require_relative 'base_command'
require_relative '../../atmos/settings_hash'
require 'climate_control'

module SimplyGenius
  module Atmos
    module Commands

      class Account < BaseCommand

        def self.description
          "Manages accounts/envs in the cloud provider"
        end

        subcommand "create", "Create a new account" do

          option ["-s", "--source-env"],
                 "SOURCE_ENV", "Base the new env on a clone of the given one"

          option ["-e", "--email"],
                 "EMAIL", "override default email used for new account"

          option ["-n", "--name"],
                 "NAME", "override default name used for new account"

          parameter "ENV",
                    "The name of the new env to create"

          def execute

            Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
              ClimateControl.modify(auth_env) do

                config = YAML.load_file(Atmos.config.config_file)

                if config['environments'][env]
                  signal_usage_error "Env '#{env}' is already present in atmos config"
                end

                source = {}
                if source_env.present?
                  source = config['environments'][source_env]
                  if source.blank?
                    signal_usage_error "Source env '#{source_env}' does not exist"
                  end
                  source = source.clone
                end

                account = Atmos.config.provider.account_manager.create_account(env, name: name, email: email)
                logger.info "Account created: #{display account}"

                source['account_id'] = account[:account_id].to_s

                new_yml = SettingsHash.add_config(
                    Atmos.config.config_file,
                    "environments.#{env}", source
                )
                logger.info("Writing out new atmos.yml containing new account")
                File.write(Atmos.config.config_file, new_yml)
              end
            end
          end
        end

        subcommand "setup_credentials", "Convenience that adds accounts to the local aws credentials store" do

          option ["-u", "--user"],
                 "USERNAME", "The username in the cloud provider", required: true

          option ["-k", "--key"],
                 "KEY", "The access key in the cloud provider"

          option ["-s", "--secret"],
                 "SECRET", "The access secret in the cloud provider"

          option ["-d", "--default"],
                 :flag, "Sets as default credentials"

          option ["-f", "--force"],
                 :flag, "Forces overwrites of existing"

          option ["-n", "--nowrite"],
                 :flag, "Trial run without writing results to files"

          def execute

            if ! key.present?
              key = ask("Input your access key: ") { |q| q.echo = "*" }
              raise ArgumentError.new("An access key is required") if key.blank?
            end
            if ! secret.present?
              secret = ask("Input your access secret: ") { |q| q.echo = "*" }
              raise ArgumentError.new("An access secret is required") if secret.blank?
            end

            Atmos.config.provider.account_manager.setup_credentials(username: user, access_key: key, access_secret: secret,
                                                                    become_default: default?, force: force?, nowrite: nowrite?)
          end
        end

      end

    end
  end
end
