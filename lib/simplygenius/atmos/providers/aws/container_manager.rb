require_relative '../../../atmos'
require 'aws-sdk-ecs'
require 'aws-sdk-ecr'
require 'aws-sdk-cloudwatchlogs'
require 'open3'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        class ContainerManager
          include GemLogger::LoggerSupport

          def initialize(provider)
            @provider = provider
          end

          def push(ecs_name, local_image,
                   ecr_repo: ecs_name, revision: nil)

            revision = Time.now.strftime('%Y%m%d%H%M%S') unless revision.present?
            result = {}

            ecr = ::Aws::ECR::Client.new
            resp = nil

            resp = ecr.get_authorization_token
            auth_data = resp.authorization_data.first
            token = auth_data.authorization_token
            endpoint = auth_data.proxy_endpoint
            user, password = Base64.decode64(token).split(':')

            # docker login into the ECR repo for the current account so that we can pull/push to it
            run("docker", "login", "-u", user, "-p", password, endpoint)#, stdin_data: token)

            image="#{ecs_name}:latest"
            ecs_image="#{endpoint.sub(/https?:\/\//, '')}/#{ecr_repo}"

            tags = ['latest', revision]
            logger.info "Tagging local image '#{local_image}' with #{tags}"
            tags.each {|t| run("docker", "tag", local_image, "#{ecs_image}:#{t}") }

            logger.info "Pushing tagged image to ECR repo #{ecs_image}"
            tags.each {|t| run("docker", "push", "#{ecs_image}:#{t}") }

            result[:remote_image] = "#{ecs_image}:#{revision}"
            return result
          end

          def deploy_task(name, remote_image)
            result = {}

            ecs = ::Aws::ECS::Client.new
            resp = nil

            resp = ecs.list_task_definitions(family_prefix: name, sort: 'DESC')
            latest_defn_arn = resp.task_definition_arns.first

            logger.info "Current task definition for #{name}: #{latest_defn_arn}"

            resp = ecs.describe_task_definition(task_definition: latest_defn_arn)
            latest_defn = resp.task_definition

            new_defn = latest_defn.to_h
            [:revision, :status, :task_definition_arn,
             :requires_attributes, :compatibilities,
             :registered_at, :registered_by].each do |attr|
              new_defn.delete(attr)
            end
            new_defn[:container_definitions].each {|c| c[:image] = remote_image}

            resp = ecs.register_task_definition(**new_defn)
            result[:task_definition] = resp.task_definition.task_definition_arn

            logger.info "Updated task=#{name} to #{result[:task_definition]} with image #{remote_image}"

            return result
          end

          def deploy(cluster, name, remote_image)
             result = deploy_task(name, remote_image)
             new_taskdef = result[:task_definition]

             # Only trigger restart if name is a service
             ecs = ::Aws::ECS::Client.new
             resp = ecs.describe_services(cluster: cluster, services: [name])

             if resp.services.size > 0
               logger.info "Updating service with new task definition: #{new_taskdef}"

               resp = ecs.update_service(cluster: cluster, service: name, task_definition: new_taskdef)

               logger.info "Updated service=#{name} on cluster=#{cluster} to #{new_taskdef} with image #{remote_image}"
             else
               logger.info "#{name} is not a service"
             end

             return result
          end

          def wait(cluster, service_name_or_task_arn)
            ecs = ::Aws::ECS::Client.new
            logger.info "Waiting for #{cluster}:#{service_name_or_task_arn} to stabilize"
            if service_name_or_task_arn =~ /arn:aws:ecs:.*:task\/.*/
              ecs.wait_until(:tasks_running, cluster: cluster, tasks: [service_name_or_task_arn])
            else
              ecs.wait_until(:services_stable, cluster: cluster, services: [service_name_or_task_arn])
            end
          end

          def remote_image(name, tag)
            ecr = ::Aws::ECR::Client.new

            resp = ecr.get_authorization_token
            endpoint = resp.authorization_data.first.proxy_endpoint

            ecs_image="#{endpoint.sub(/https?:\/\//, '')}/#{name}"
            tagged_image = "#{ecs_image}:#{tag}"

            return tagged_image
          end

          def list_image_tags(cluster, name)
            result = {tags: [], latest: nil, current: nil}
            latest_digest = nil

            ecs = ::Aws::ECS::Client.new
            ecr = ::Aws::ECR::Client.new

            resp = ecs.describe_services(services: [name], cluster: cluster)
            if resp.services.size == 1
              task_def = resp.services.first.task_definition
              resp = ecs.describe_task_definition(task_definition: task_def)
              image = resp.task_definition.container_definitions.first.image
              result[:current] = image.sub(/^.*:/, '')
            else
              raise "No services found for '#{name}' in cluster '#{cluster}'"
            end

            # TODO: handle pagination?
            resp = ecr.list_images(repository_name: name, filter: {tag_status: "TAGGED"}, max_results: 1000)
            if resp.image_ids.size > 0

              images = resp.image_ids

              images.each do |i|
                if i.image_tag == 'latest'
                  latest_digest = i.image_digest
                end

                result[:tags] << i.image_tag
              end

              if latest_digest
                images.each do |i|
                  if i.image_digest == latest_digest && i.image_tag != 'latest'
                    result[:latest] = i.image_tag
                    break
                  end
                end
                # Handle if latest tag isn't some other tag
                result[:latest] = 'latest' if result[:latest].nil?
              end

              result[:tags].sort!
            else
              raise "No images found for '#{name}'"
            end

            return result
          end

          def run_task(cluster, name, command:, waiter_log_pattern: nil, launch_type: "FARGATE")
            result = {}

            ecs = ::Aws::ECS::Client.new
            resp = nil

            task_opts = {
                count: 1,
                cluster: cluster,
                task_definition: name,
                launch_type: launch_type,
                overrides: {container_overrides: [{name: name, command: command}]}
            }

            defn_arn = nil
            resp = ecs.describe_services(cluster: cluster, services: [name])
            if resp.services.size > 0
              svc = resp.services.first
              task_opts[:launch_type] = svc.launch_type
              task_opts[:network_configuration] = svc.network_configuration.to_h
              defn_arn = svc.task_definition
              logger.info "Running service task as '#{task_opts[:launch_type]}'"
            else
              resp = ecs.list_task_definitions(family_prefix: name, sort: 'DESC')
              defn_arn = resp.task_definition_arns.first
              logger.info "Running task as '#{task_opts[:launch_type]}'"
            end

            raise "Could not find a task definition in AWS for '#{name}'" if defn_arn.blank?

            resp = ecs.describe_task_definition(task_definition: defn_arn)
            defn = resp.task_definition
            raise "Invalid Launch type '#{launch_type}'" unless (defn.requires_compatibilities + defn.compatibilities).include?(launch_type)

            log_config = defn.container_definitions.first.log_configuration
            log_group = nil
            log_stream_prefix = nil
            if log_config && log_config.log_driver == "awslogs"
              log_group = log_config.options["awslogs-group"]
              log_stream_prefix = log_config.options["awslogs-stream-prefix"]
            end
            if waiter_log_pattern && log_group.nil?
              logger.error "Cannot wait on a log unless task definition uses cloudwatch for logging"
              waiter_log_pattern = nil
            end

            resp = ecs.run_task(**task_opts)
            task_arn = result[:task_arn] = resp.tasks.first.task_arn
            task_id = result[:task_id] = task_arn.split('/').last

            logger.info "Waiting for task to start"
            ecs.wait_until(:tasks_running, cluster: cluster, tasks: [task_id])

            if waiter_log_pattern
              cwl = ::Aws::CloudWatchLogs::Client.new

              waiter_regexp = Regexp.new(waiter_log_pattern)
              log_stream = "#{log_stream_prefix}/#{name}/#{task_id}"
              logger.info "Task started, looking for log pattern in group=#{log_group} stream=#{log_stream}"
              log_token = nil
              10.times do
                resp = cwl.get_log_events(log_group_name: log_group, log_stream_name: log_stream, start_from_head: true, next_token: log_token)
                resp.events.each do |e|
                  logger.debug("Task log #{e.timestamp}: #{e.message}")
                  if e.message =~ waiter_regexp
                    result[:log_match] = Regexp.last_match
                    return result # return, not break due to doubly nested iterator
                  end
                end
                log_token = resp.next_forward_token
                sleep 1
              end
            end

            return result
          end

          def stop_task(cluster, task)
            ecs = ::Aws::ECS::Client.new
            resp = ecs.stop_task(cluster: cluster, task: task)
          end

        private

          def run(*args, **opts)
            logger.debug("Running: #{args}")
            stdout, status = Open3.capture2e(ENV, *args, **opts)
            logger.debug(stdout)
            raise "Failed to run #{args}: #{stdout}" unless status.success?
            return stdout
          end

        end

      end
    end
  end
end
