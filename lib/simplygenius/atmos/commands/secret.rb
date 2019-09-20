require_relative 'base_command'
require 'climate_control'

module SimplyGenius
  module Atmos
    module Commands

      class Secret < BaseCommand

        def self.description
          "Manages application secrets"
        end

        subcommand "get", "Gets the secret value" do

          parameter "KEY",
                    "The secret key"

          def execute

            Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
              ClimateControl.modify(auth_env) do
                value = Atmos.config.provider.secret_manager.get(key)
                logger.info "Secret value for #{key}:"
                puts value
              end
            end

          end

        end

        subcommand "set", "Sets the secret value" do

          option ["-f", "--force"],
                 :flag, "forces updates for pre-existing secret\n",
                 default: false

          parameter "KEY",
                    "The secret key"

          parameter "VALUE",
                    "The secret value"

          def execute

            Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
              ClimateControl.modify(auth_env) do
                Atmos.config.provider.secret_manager.set(key, value, force: force?)
                logger.info "Secret set for #{key}"
              end
            end

          end

        end

        subcommand "list", "Lists all secret keys" do

          def execute

            Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
              ClimateControl.modify(auth_env) do
                logger.info "Secret keys are:"
                Atmos.config.provider.secret_manager.to_h.keys.each {|k| logger.info k}
              end
            end

          end

        end

        subcommand "delete", "Deletes the secret key/value" do

          parameter "KEY",
                    "The secret key"

          def execute

            Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
              ClimateControl.modify(auth_env) do
                value = Atmos.config.provider.secret_manager.get(key)
                Atmos.config.provider.secret_manager.delete(key)
                logger.info "Deleted secret: #{key}=#{value}"
              end
            end

          end

        end

      end

    end
  end
end
