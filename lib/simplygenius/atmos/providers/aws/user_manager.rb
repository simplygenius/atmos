require_relative '../../../atmos'
require_relative '../../../atmos/otp'
require 'aws-sdk-iam'
require 'securerandom'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        class UserManager
          include GemLogger::LoggerSupport
          include FileUtils

          def initialize(provider)
            @provider = provider
          end

          def create_user(user_name)
            result = {}
            client = ::Aws::IAM::Client.new
            resource = ::Aws::IAM::Resource.new

            user = resource.user(user_name)

            if user.exists?
              logger.info "User '#{user_name}' already exists"
            else
              logger.info "Creating new user '#{user_name}'"
              user = resource.create_user(user_name: user_name)
              client.wait_until(:user_exists, user_name: user_name)
              logger.debug "User created, user_name=#{user_name}"
            end

            result[:user_name] = user_name

            return result
          end

          def set_groups(user_name, groups, force: false)
            result = {}
            resource = ::Aws::IAM::Resource.new

            user = resource.user(user_name)

            existing_groups = user.groups.collect(&:name)
            groups_to_add = groups -  existing_groups
            groups_to_remove = existing_groups - groups

            result[:groups] = existing_groups

            groups_to_add.each do |group|
              logger.debug "Adding group: #{group}"
              user.add_group(group_name: group)
              result[:groups] << group
            end

            if force
              groups_to_remove.each do |group|
                logger.debug "Removing group: #{group}"
                user.remove_group(group_name: group)
                result[:groups].delete(group)
              end
            end

            logger.info "User associated with groups=#{result[:groups]}"

            return result
          end

          def enable_login(user_name, force: false)
            result = {}
            resource = ::Aws::IAM::Resource.new

            user = resource.user(user_name)

            password = ""
            classes = [/[a-z]/, /[A-Z]/, /[0-9]/, /[!@#$%^&*()_+\-=\[\]{}|']/]
            while ! classes.all? {|c| password =~ c }
              password = SecureRandom.base64(15)
            end

            exists = false
            begin
              user.login_profile.create_date
              exists = true
            rescue ::Aws::IAM::Errors::NoSuchEntity
              exists = false
            end

            if exists
              logger.info "User login already exists"
              if force
                user.login_profile.update(password: password, password_reset_required: true)
                result[:password] = password
                logger.info "Updated user login with password=#{password}"
              end
            else
              user.create_login_profile(password: password, password_reset_required: true)
              result[:password] = password
              logger.info "User login enabled with password=#{password}"
            end

            return result
          end

          def enable_mfa(user_name, force: false)
            result = {}
            client = ::Aws::IAM::Client.new
            resource = ::Aws::IAM::Resource.new

            user = resource.user(user_name)

            if user.mfa_devices.first
              logger.info "User mfa devices already exist"
              if force
                logger.info "Deleting old mfa devices"
                user.mfa_devices.each do |dev|
                  dev.disassociate
                  client.delete_virtual_mfa_device(serial_number: dev.serial_number)
                  Otp.instance.remove(user_name)
                end
              else
                return result
              end
            end

            resp = client.create_virtual_mfa_device(
              virtual_mfa_device_name: user_name
            )

            serial = resp.virtual_mfa_device.serial_number
            seed = resp.virtual_mfa_device.base_32_string_seed

            Otp.instance.add(user_name, seed)
            code1 = Otp.instance.generate(user_name)
            interval = (30 - (Time.now.to_i % 30)) + 1
            logger.info "Waiting for #{interval}s to generate second otp key for enablement"
            sleep interval
            code2 = Otp.instance.generate(user_name)
            raise "MFA codes should not be the same" if code1 == code2

            resp = client.enable_mfa_device({
              user_name: user_name,
              serial_number: serial,
              authentication_code_1: code1,
              authentication_code_2: code2,
            })

            result[:mfa_secret] = seed

            return result
          end

          def enable_access_keys(user_name, force: false)
            result = {}
            resource = ::Aws::IAM::Resource.new

            user = resource.user(user_name)

            if user.access_keys.first
              logger.info "User access keys already exist"
              if force
                logger.info "Deleting old access keys"
                user.access_keys.each do |key|
                  key.delete
                end
              else
                return result
              end
            end

            # TODO: auto add to ~/.aws/credentials and config
            key_pair = user.create_access_key_pair
            result[:key] = key_pair.access_key_id
            result[:secret] = key_pair.secret
            logger.debug "User keys generated key=#{key_pair.access_key_id}, secret=#{key_pair.secret}"

            return result
          end

          def set_public_key(user_name, public_key, force: false)
            result = {}
            client = ::Aws::IAM::Client.new
            resource = ::Aws::IAM::Resource.new

            user = resource.user(user_name)
            keys = client.list_ssh_public_keys(user_name: user_name).ssh_public_keys
            if keys.size > 0
              logger.info "User ssh public keys already exist"
              if force
                logger.info "Deleting old ssh public keys"
                keys.each do |key|
                  client.delete_ssh_public_key(user_name: user_name,
                                               ssh_public_key_id: key.ssh_public_key_id)
                end
              else
                return result
              end
            end

            client.upload_ssh_public_key(user_name: user_name, ssh_public_key_body: public_key)
            logger.debug "User public key assigned: #{public_key}"

            return result
          end

        end

      end
    end
  end
end
