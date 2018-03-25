require 'atmos'
require 'aws-sdk-ecs'
require 'aws-sdk-ecr'
require 'open3'

module Atmos
  module Providers
    module Aws

      class ContainerManager
        include GemLogger::LoggerSupport

        def initialize(provider)
          @provider = provider
        end

        def push(ecs_name, local_image,
                 ecr_repo: ecs_name, revision: Time.now.strftime('%Y%m%d%H%M%S'))

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

          logger.info "Pushing tagged image to ECR repo"
          tags.each {|t| run("docker", "push", "#{ecs_image}:#{t}") }

          result[:remote_image] = "#{ecs_image}:#{revision}"
          return result
        end

        def deploy_task(task, remote_image)
          result = {}

          ecs = ::Aws::ECS::Client.new
          resp = nil

          resp = ecs.list_task_definitions(family_prefix: task, sort: 'DESC')
          latest_defn_arn = resp.task_definition_arns.first

          logger.info "Latest task definition: #{latest_defn_arn}"

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

          logger.info "Updated task=#{task} to #{result[:task_definition]} with image #{remote_image}"

          return result
        end

        def deploy_service(cluster, service, remote_image)
           result = {}

           ecs = ::Aws::ECS::Client.new
           resp = nil

           # Get current task definition name from service
           resp = ecs.describe_services(cluster: cluster, services: [service])
           current_defn_arn = resp.services.first.task_definition
           defn_name = current_defn_arn.split("/").last.split(":").first

           logger.info "Current task definition (name=#{defn_name}): #{current_defn_arn}"
           result = deploy_task(defn_name, remote_image)
           new_taskdef = result[:task_definition]

           logger.info "Updating service with new task definition: #{new_taskdef}"

           resp = ecs.update_service(cluster: cluster, service: service, task_definition: new_taskdef)

           logger.info "Updated service=#{service} on cluster=#{cluster} to #{new_taskdef} with image #{remote_image}"

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
