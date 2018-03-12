require 'atmos'
require 'aws-sdk-iam'
require 'securerandom'

module Atmos
  module Providers
    module Aws

      class UserManager
        include GemLogger::LoggerSupport
        include FileUtils

        def initialize(provider)
          @provider = provider
        end

        def create_user(user_name, groups, login: false, keys: false, public_key: nil)
          result = {}
          client = ::Aws::IAM::Client.new
          resource = ::Aws::IAM::Resource.new

          user = resource.create_user(user_name: user_name)
          client.wait_until(:user_exists, user_name: user_name)
          result[:user_name] = user_name
          logger.debug "User created, user_name=#{user_name}"

          groups.each do |group|
            user.add_group(group_name: group)
            result[:groups] ||= []
            result[:groups] << group
          end
          logger.debug "User associated with groups=#{groups.inspect}"

          if login
            password = SecureRandom.base64(15)
            user.create_login_profile(password: password, password_reset_required: true)
            result[:password] = password
            logger.debug "User login enabled with password=#{password}"
          end

          if keys
            key_pair = user.create_access_key_pair
            result[:key] = key_pair.access_key_id
            result[:secret] = key_pair.secret
            logger.debug "User keys generated key=#{key_pair.access_key_id}, secret=key_pair.secret"
          end

          if public_key
            client.upload_ssh_public_key(user_name: user_name, ssh_public_key_body: public_key)
            logger.debug "User public key assigned: #{public_key}"
          end

          return result
        end

        def modify_groups(user_name, groups, add: false)
          result = {}
          resource = ::Aws::IAM::Resource.new

          user = resource.user(user_name)
          result = result.merge(user.data)

          result[:groups] ||= []
          if add
            result[:groups].concat(user.groups.collect(&:name))
          else
            user.groups.each do |group|
              logger.debug "Removing group: #{group}"
              user.remove_group(group_name: group.name)
            end
            result[:groups] = []
          end

          groups.each do |group|
            logger.debug "Adding group: #{group}"
            user.add_group(group_name: group)
            result[:groups] << group
          end

          logger.debug "User associated with groups=#{result[:groups]}"

          return result
        end

      end

    end
  end
end
