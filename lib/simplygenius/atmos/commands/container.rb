require_relative 'base_command'
require_relative '../../atmos/settings_hash'
require 'climate_control'

module SimplyGenius
  module Atmos
    module Commands

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

          option ["-v", "--revision"],
                 "REVISION", "Use as the remote image revision\n"

          parameter "NAME ...",
                    "The name of the service (or task) to deploy\nWhen multiple, the first is the primary, and\nthe rest get deployed with its image"

          def default_image
            name_list.first
          end

          def execute
            Atmos.config.provider.auth_manager.authenticate(ENV, role: role) do |auth_env|
              ClimateControl.modify(auth_env) do
                mgr = Atmos.config.provider.container_manager

                primary_name = name_list.first

                result = mgr.push(primary_name, image, revision: revision)

                name_list.each do |name|
                  resp = mgr.deploy(cluster, name, result[:remote_image])
                  result[:task_definitions] ||= []
                  result[:task_definitions] << resp[:task_definition]
                end

                logger.info "Container deployed:\n #{display result}"
              end
            end
          end
        end

      end

    end
  end
end
