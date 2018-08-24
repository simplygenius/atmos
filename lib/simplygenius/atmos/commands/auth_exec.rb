require_relative 'base_command'
require 'climate_control'

module SimplyGenius
  module Atmos
    module Commands

      class AuthExec < BaseCommand

        def self.description
          "Exec subprocess with an authenticated environment"
        end

        option ["-r", "--role"],
               'ROLE', "overrides assume role name\n"

        parameter "COMMAND ...", "command to exec", :attribute_name => :command

        def execute
          Atmos.config.provider.auth_manager.authenticate(ENV, role: role) do |auth_env|
            result = system(auth_env, *command)
            if ! result
              logger.error("Process failed: #{command}")
              exit(1)
            end
          end

        end

      end

    end
  end
end
