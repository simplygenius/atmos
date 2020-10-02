require_relative '../../../atmos'
require 'aws-sdk-organizations'
require 'inifile'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        class AccountManager
          include GemLogger::LoggerSupport
          include FileUtils

          def initialize(provider)
            @provider = provider
          end

          def create_account(env, name: nil, email: nil)
            result = {}
            org = ::Aws::Organizations::Client.new
            resp = nil
            name ||= "Atmos #{env} account"

            begin
              logger.info "Looking up organization"
              resp = org.describe_organization()
              logger.debug "Described organization: #{resp.to_h}"
            rescue ::Aws::Organizations::Errors::AWSOrganizationsNotInUseException
              logger.info "Organization doesn't exist, creating"
              resp = org.create_organization()
              logger.debug "Created organization: #{resp.to_h}"
            end

            if email.blank?
              master_email = resp.organization.master_account_email
              email = master_email.sub('@', "+#{env}@")
            end
            result[:email] = email
            result[:name] = name


            begin
              logger.info "Creating account named #{name}"
              resp = org.create_account(account_name: name, email: email)
            rescue ::Aws::Organizations::Errors::FinalizingOrganizationException
              logger.info "Waiting to retry account creation as the organization needs to finalize"
              logger.info "This will eventually succeed after receiving a"
              logger.info "'Consolidated Billing verification' email from AWS"
              logger.info "You can leave this running or cancel and restart later."
              sleep 60
              retry
            end

            logger.debug "Created account: #{resp.to_h}"

            status_id = resp.create_account_status.id
            status = resp.create_account_status.state
            account_id = resp.create_account_status.account_id

            while status =~ /in_progress/i
              logger.info "Waiting for account creation to complete, status: #{status}"
              resp = org.describe_create_account_status(create_account_request_id: status_id)
              logger.debug("Account creation status check: #{resp.to_h}")
              status = resp.create_account_status.state
              account_id = resp.create_account_status.account_id
              sleep 5
            end

            if status =~ /failed/i
              logger.error "Failed to create account: #{resp.create_account_status.failure_reason}"
              exit(1)
            end

            result[:account_id] = account_id

            return result
          end

          def setup_credentials(username:, access_key:, access_secret:, become_default: false, force: false, nowrite: false)
            creds = File.expand_path("~/.aws/credentials")
            config = File.expand_path("~/.aws/config")

            creds_data = IniFile.load(creds) || IniFile.new
            config_data = IniFile.load(config) || IniFile.new

            org = Atmos.config["org"]
            accounts = Atmos.config.account_hash

            # Our entrypoint account (the ops env/account) is the account we
            # have credentials for, and typically one authenticate using the
            # credentials for that account, then assume role (<env>-admin) to
            # actually operate in each env, even for the ops account
            ops_config = Atmos::Config.new("ops")
            entrypoint_section = become_default ? "default" : org
            entrypoint_config_section = become_default ? "default" : "profile #{org}"
            write_entrypoint = true
            if config_data.has_section?(entrypoint_config_section)  || creds_data.has_section?(entrypoint_section)
              if force
                logger.info "Overwriting pre-existing sections: '#{entrypoint_config_section}'/'#{entrypoint_section}'"
              else
                logger.info "Skipping pre-existing sections (use force to overwrite): '#{entrypoint_config_section}'/'#{entrypoint_section}'"
                write_entrypoint = false
              end
            end
            if write_entrypoint
              config_data[entrypoint_config_section]["region"] = ops_config["region"]
              creds_data[entrypoint_section]["aws_access_key_id"] = access_key
              creds_data[entrypoint_section]["aws_secret_access_key"] = access_secret
              creds_data[entrypoint_section]["mfa_serial"] = "arn:aws:iam::#{accounts["ops"]}:mfa/#{username}"
            end

            accounts.each do |env, account_id|
              env_config = Atmos::Config.new(env)

              section = "#{org}-#{env}"
              config_section = "profile #{section}"

              if config_data.has_section?(config_section)  || creds_data.has_section?(section)
                if force
                  logger.info "Overwriting pre-existing sections: '#{config_section}'/'#{section}'"
                else
                  logger.info "Skipping pre-existing sections (use force to overwrite): '#{config_section}'/'#{section}'"
                  next
                end
              end

              config_data[config_section]["source_profile"] = entrypoint_section
              role_name = env_config["auth.assume_role_name"]
              config_data[config_section]["role_arn"] = "arn:aws:iam::#{account_id}:role/#{role_name}"
            end

            if nowrite
              logger.info "Trial run only, would write the following:\n"
              puts "*** #{config}:\n\n"
              puts config_data.to_s

              puts "\n\n*** #{creds}:\n\n"
              puts creds_data.to_s
            else
              logger.info "Writing credentials to disk"
              mkdir_p(File.dirname(config))
              mv config, "#{config}.bak" if File.exist?(config)
              mv creds, "#{creds}.bak" if File.exist?(creds)
              config_data.write(filename: config)
              creds_data.write(filename: creds)
            end

          end
        end

      end
    end
  end
end
