require 'atmos/commands/base_command'
require 'atmos/settings_hash'
require 'climate_control'

module Atmos::Commands

  class Container < BaseCommand

    def self.description
      "Manages containers in the cloud provider"
    end

    subcommand "deploy", "Deploy a container" do

      option ["-c", "--cluster"],
             "CLUSTER", "The cluster name\n",
             required: true

      option ["-r", "--role"],
             "ROLE", "The role to assume when deploying\n"

      option ["-i", "--image"],
             "IMAGE", "The local container image to deploy\nDefaults to service/task name"

      option ["-t", "--task"],
             :flag, "Deploy as a task, not a service\n"

      parameter "NAME",
                "The name of the service (or task) to deploy"

      def default_image
        name
      end

      def execute
        Atmos.config.provider.auth_manager.authenticate(ENV, role: role) do |auth_env|
          ClimateControl.modify(auth_env) do
            mgr = Atmos.config.provider.container_manager

            result = mgr.push(name, image)
            if task?
              result = result.merge(mgr.deploy_task(name, result[:remote_image]))
            else
              result = result.merge(mgr.deploy_service(cluster, name, result[:remote_image]))
            end

            logger.info "Container deployed:\n #{display result}"
          end
        end
      end
    end

  end

end
