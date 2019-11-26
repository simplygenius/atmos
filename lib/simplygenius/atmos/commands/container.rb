require_relative 'base_command'
require_relative '../../atmos/settings_hash'
require_relative '../../atmos/ui'
require 'climate_control'

module SimplyGenius
  module Atmos
    module Commands

      class Container < BaseCommand
        include UI

        def self.description
          "Manages containers in the cloud provider"
        end

        option ["-c", "--cluster"],
               "CLUSTER", "The cluster name\n",
               required: true

        option ["-r", "--role"],
               "ROLE", "The role to assume when deploying\n"

        subcommand "push", "Only push a container image without activating it" do

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

                logger.info "Container pushed:\n #{display result}"
              end
            end
          end

        end

        subcommand "activate", "Activate a container that has already been pushed" do

          option ["-v", "--revision"],
                 "REVISION", "Use the given revision of the pushed image\nto activate\n"

          option ["-l", "--list"],
                 :flag, "List the most recent pushed images\n"

          option ["-t", "--tagcount"],
                 "N", "Only show the last N items when listing\n",
                 default: 10 do |s|
            Integer(s)
          end

          parameter "NAME ...",
                    "The name of the service (or task) to activate\nWhen multiple, the first is the primary, and\nthe rest get activated with its image"

          def execute
            Atmos.config.provider.auth_manager.authenticate(ENV, role: role) do |auth_env|
              ClimateControl.modify(auth_env) do
                mgr = Atmos.config.provider.container_manager
                primary_name = name_list.first

                if list?
                  tags =  mgr.list_image_tags(cluster, primary_name)
                  logger.info "Recent revisions:\n"
                  tags[:tags].last(tagcount).each {|t| logger.info "\t#{t}"}
                  logger.info("")
                  logger.info("Currently active revision is: #{tags[:current]}") if tags[:current]
                  logger.info("The revision associated with the `latest` tag is: #{tags[:latest]}") if tags[:latest]
                  return
                end

                rev = revision
                if rev.nil? && !list?
                  tags =  mgr.list_image_tags(cluster, primary_name)
                  logger.info("Currently active revision is: #{tags[:current]}") if tags[:current]
                  logger.info("The revision associated with the `latest` tag is: #{tags[:latest]}") if tags[:latest]
                  logger.info("")

                  rev = choose do |menu|
                    menu.prompt = "Which revision would you like to activate? "
                    menu.choices(* tags[:tags].last(tagcount))
                  end
                end

                remote_image = mgr.remote_image(primary_name, rev)
                result = {}
                name_list.each do |name|
                  resp = mgr.deploy(cluster, name, remote_image)
                  result[:task_definitions] ||= []
                  result[:task_definitions] << resp[:task_definition]
                end

                logger.info "Container activated:\n #{display result}"
              end
            end
          end

        end

        subcommand "deploy", "Push and activate a container" do

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
            # TODO: use local_name_prefix for cluster name and repo/service name?
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

        subcommand "console", "Spawn a console and attach to it" do

          option ["-p", "--persist"],
                 :flag, "Leave the task running after disconnect\n"

          parameter "NAME",
                    "The name of the service (or task) to attach\nthe console to"

          def execute
            Atmos.config.provider.auth_manager.authenticate(ENV, role: role) do |auth_env|
              ClimateControl.modify(auth_env) do
                mgr = Atmos.config.provider.container_manager
                remote_command = Array(Atmos.config['atmos.container.console.remote_command'])
                remote_persist_command = Array(Atmos.config['atmos.container.console.remote_persist_command'])
                log_pattern = Atmos.config['atmos.container.console.remote_log_pattern']
                local_command = Atmos.config['atmos.container.console.local_command']

                cmd = persist? ? remote_persist_command : remote_command
                logger.debug "Running remote command: #{cmd.join(" ")}"
                result = mgr.run_task(cluster, name, command: cmd, waiter_log_pattern: log_pattern)
                logger.debug "Run task result: #{result}"
                begin
                  match = result[:log_match]
                  local_command = local_command.collect {|c| match.names.each {|n| c = c.gsub("<#{n}>", match[n]) }; c }
                  system(*local_command)
                ensure
                  if persist?
                    logger.info "Console disconnected, you can reconnect with: #{local_command.join(" ")}"
                  else
                    logger.info "Console complete, stopping task"
                    mgr.stop_task(cluster, result[:task_id])
                  end
                end
              end
            end
          end
        end

      end

    end
  end
end
