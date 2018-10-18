require_relative 'base_command'
require_relative '../../atmos/terraform_executor'

module SimplyGenius
  module Atmos
    module Commands

      class Terraform < BaseCommand

        def self.description
          "Runs terraform"
        end

        # override so we can pass all options/flags/parameters directly to
        # terraform instead of having clamp parse them
        def parse(arguments)
          @terraform_arguments = arguments
        end

        def execute

          unless Atmos.config.is_atmos_repo?
            signal_usage_error <<~EOF
              Atmos can only run terraform from a location configured for atmos. 
              Have you run atmos init?"
            EOF
          end

          Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
            begin
              exe = TerraformExecutor.new(process_env: auth_env)
              get_modules = @terraform_arguments.delete("--get-modules")
              exe.run(*@terraform_arguments, get_modules: get_modules.present?)
            rescue TerraformExecutor::ProcessFailed => e
              logger.error(e.message)
            end
          end
        end

      end

    end
  end
end
