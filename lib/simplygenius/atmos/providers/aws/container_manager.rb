require_relative '../../../atmos'
require 'aws-sdk-ecs'
require 'aws-sdk-ecr'
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
             :requires_attributes, :compatibilities].each do |attr|
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
