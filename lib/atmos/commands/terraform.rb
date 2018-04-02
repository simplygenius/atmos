require 'atmos/commands/base_command'
require 'atmos/terraform_executor'

module Atmos::Commands

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

          # TODO: hack to allow apply/etc for bootstrap group
          # Fix this once we allow more extensive recipe grouping
          working_group = nil
          @terraform_arguments.each_with_index do |a, i|
            if a == "--group"
              @terraform_arguments.delete_at(i)
              working_group = @terraform_arguments.delete_at(i)
              break
            end
          end

          exe = Atmos::TerraformExecutor.new(process_env: auth_env, working_group: working_group)
          get_modules = @terraform_arguments.delete("--get-modules")
          exe.run(*@terraform_arguments, get_modules: get_modules.present?)
        rescue Atmos::TerraformExecutor::ProcessFailed => e
          logger.error(e.message)
        end
      end
    end

  end

end
