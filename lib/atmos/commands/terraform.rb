require 'atmos'
require 'clamp'
require 'atmos/terraform_executor'

module Atmos::Commands

  class Terraform < Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      "Runs terraform"
    end

    # override so we can pass all options/flags/parameters directly to
    # terraform instead of having clamp parse them
    def parse(arguments)
      @terraform_arguments = arguments
    end

    def execute
      signal_usage_error "Atmos can only run terraform from a location configured for atmos.\nHave you run atmos init?" unless Atmos.config.is_atmos_repo?

      Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
        begin
          exe = Atmos::TerraformExecutor.new(process_env: auth_env)
          exe.run(*@terraform_arguments)
        rescue Atmos::TerraformExecutor::ProcessFailed => e
          logger.error(e.message)
        end
      end
    end

  end

end
