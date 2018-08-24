require 'simplygenius/atmos/providers/aws/container_manager'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe ContainerManager do

          let(:manager) { described_class.new(nil) }

          before(:all) do
            @orig_stub_responses = ::Aws.config[:stub_responses]
            ::Aws.config[:stub_responses] = true
          end

          after(:all) do
            ::Aws.config[:stub_responses] = @orig_stub_responses
          end

          describe "run" do

            it "runs a command" do
              expect(Open3).to receive(:capture2e).
                  with(ENV, "my", "cmd", stdin_data: "foo").
                  and_return(["output", double(Process::Status, :success? => true)])
              expect(manager.send(:run, "my", "cmd", stdin_data: "foo")).to eq("output")
            end

            it "raises on failure" do
              expect(Open3).to receive(:capture2e).
                  with(ENV, "my", "cmd", stdin_data: "foo").
                  and_return(["", double(Process::Status, :success? => false)])
              expect { manager.send(:run, "my", "cmd", stdin_data: "foo") }.to raise_error(/Failed to run/)
            end

          end

          describe "push" do

            it "pushes image to repo" do
              ecr = ::Aws::ECR::Client.new
              expect(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              name = "myname"
              image = "myimage"
              user = "user"
              password = "password"
              endpoint = 'https://repo.amazon.com'
              repo = "repo.amazon.com/#{name}"
              token = Base64.encode64("#{user}:#{password}")
              ecr.stub_responses(:get_authorization_token, authorization_data: [
                  {authorization_token: token, proxy_endpoint: endpoint}
              ])

              expect(manager).to receive(:run).
                  with("docker", "login", "-u", user, "-p", password, endpoint).ordered
              expect(manager).to receive(:run).
                  with("docker", "tag", image, "#{repo}:latest").ordered
              expect(manager).to receive(:run).
                  with("docker", "tag", image, "#{repo}:rev").ordered
              expect(manager).to receive(:run).
                  with("docker", "push", "#{repo}:latest").ordered
              expect(manager).to receive(:run).
                  with("docker", "push", "#{repo}:rev").ordered

              result = manager.push(name, image, revision: "rev")
              expect(result[:remote_image]).to eq("#{repo}:rev")
            end

          end

          describe "deploy_task" do

            it "deploys the task" do
              ecs = ::Aws::ECS::Client.new
              expect(::Aws::ECS::Client).to receive(:new).and_return(ecs)

              name = "myname"
              repo = "repo.amazon.com/#{name}"
              ver = 11
              arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/#{name}:#{ver}"
              ecs.stub_responses(:list_task_definitions, task_definition_arns: [
                  arn
              ])
              #ecs.stub_responses(:describe_task_definition, task_definition: ecs.stub_data(:task_definition))
              #ecs.stub_responses(:register_task_definition, task_definition: )

              result = manager.deploy_task(name, repo)
              expect(result[:task_definition]).to eq("String")
            end

          end

          describe "deploy_service" do

            it "deploys the service" do
              ecs = ::Aws::ECS::Client.new
              allow(::Aws::ECS::Client).to receive(:new).and_return(ecs)

              cluster = "mycluster"
              name = "myname"
              repo = "repo.amazon.com/#{name}"
              ver = 11
              arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/#{name}:#{ver}"
              ecs.stub_responses(:list_task_definitions, task_definition_arns: [
                  arn
              ])
              ecs.stub_responses(:describe_services, services: [
                  {task_definition: arn}
              ])
              #ecs.stub_responses(:describe_task_definition, task_definition: ecs.stub_data(:task_definition))
              #ecs.stub_responses(:register_task_definition, task_definition: )

              result = manager.deploy_service(cluster, name, repo)
              expect(result[:task_definition]).to eq("String")
            end

          end

        end

      end
    end
  end
end
