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
              #ecs.stub_responses(:register_task_definition, task_definition: ecs.stub_data(:task_definition))

              result = manager.deploy_task(name, repo)
              expect(result[:task_definition]).to eq("String")
            end

          end

          describe "deploy" do

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

              expect(ecs).to receive(:update_service).and_call_original
              result = manager.deploy(cluster, name, repo)
              expect(result[:task_definition]).to eq("String")
            end

            it "deploys task (not service)" do
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
              ecs.stub_responses(:describe_services, services: [])

              expect(ecs).to_not receive(:update_service)
              result = manager.deploy(cluster, name, repo)
              expect(result[:task_definition]).to eq("String")
            end

          end

          describe "remote_image" do

            it "constructs the remote image" do
              ecr = ::Aws::ECR::Client.new
              expect(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              name = "myname"
              endpoint = 'https://repo.amazon.com'
              repo = "repo.amazon.com/#{name}"
              ecr.stub_responses(:get_authorization_token, authorization_data: [
                  {proxy_endpoint: endpoint}
              ])

              result = manager.remote_image(name, "rev")
              expect(result).to eq("#{repo}:rev")
            end

          end

          describe "list_image_tags" do

            it "fails when no service" do
              ecs = ::Aws::ECS::Client.new
              allow(::Aws::ECS::Client).to receive(:new).and_return(ecs)

              cluster = "mycluster"
              name = "myname"

              ecs.stub_responses(:describe_services, services: [])
              expect(ecs).to receive(:describe_services).with(services: [name], cluster: cluster).and_call_original
              expect { manager.list_image_tags(cluster, name) }.to raise_error(RuntimeError, /No services found/)
            end

            it "fails when no images" do
              ecs = ::Aws::ECS::Client.new
              allow(::Aws::ECS::Client).to receive(:new).and_return(ecs)
              ecr = ::Aws::ECR::Client.new
              allow(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              cluster = "mycluster"
              name = "myname"
              tag = "mytag"
              td_arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/#{name}:1"
              image = "repo.amazon.com/#{name}:#{tag}"

              ecs.stub_responses(:describe_services, services: [{task_definition: td_arn}])
              ecs.stub_responses(:describe_task_definition, task_definition: {container_definitions: [{image: image}]})
              ecr.stub_responses(:list_images, image_ids: [])

              expect(ecs).to receive(:describe_services).with(services: [name], cluster: cluster).and_call_original
              expect(ecs).to receive(:describe_task_definition).with(task_definition: td_arn).and_call_original
              expect(ecr).to receive(:list_images).with(repository_name: name, filter: {tag_status: "TAGGED"}, max_results: 1000).and_call_original

              expect { manager.list_image_tags(cluster, name) }.to raise_error(RuntimeError, /No images found/)
            end

            it "returns the tags" do
              ecs = ::Aws::ECS::Client.new
              allow(::Aws::ECS::Client).to receive(:new).and_return(ecs)
              ecr = ::Aws::ECR::Client.new
              allow(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              cluster = "mycluster"
              name = "myname"
              tag = "mytag"
              digest = "0x123"
              td_arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/#{name}:1"
              image = "repo.amazon.com/#{name}:#{tag}"

              ecs.stub_responses(:describe_services, services: [{task_definition: td_arn}])
              ecs.stub_responses(:describe_task_definition, task_definition: {container_definitions: [{image: image}]})
              ecr.stub_responses(:list_images, image_ids: [
                  {image_tag: "latest", image_digest: '0x321'},
                  {image_tag: tag, image_digest: digest},
                  {image_tag: '1tag', image_digest: '0x321'},
              ])

              expect(ecs).to receive(:describe_services).with(services: [name], cluster: cluster).and_call_original
              expect(ecs).to receive(:describe_task_definition).with(task_definition: td_arn).and_call_original
              expect(ecr).to receive(:list_images).with(repository_name: name, filter: {tag_status: "TAGGED"}, max_results: 1000).and_call_original

              result = manager.list_image_tags(cluster, name)
              expect(result).to be_a(Hash)
              expect(result[:tags]).to eq(["1tag", "latest", "mytag"]) # sorted
              expect(result[:latest]).to eq("1tag")
              expect(result[:current]).to eq("mytag")
            end

            it "handles other latest tag" do
              ecs = ::Aws::ECS::Client.new
              allow(::Aws::ECS::Client).to receive(:new).and_return(ecs)
              ecr = ::Aws::ECR::Client.new
              allow(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              cluster = "mycluster"
              name = "myname"
              tag = "mytag"
              digest = "0x123"
              td_arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/#{name}:1"
              image = "repo.amazon.com/#{name}:#{tag}"

              ecs.stub_responses(:describe_services, services: [{task_definition: td_arn}])
              ecs.stub_responses(:describe_task_definition, task_definition: {container_definitions: [{image: image}]})
              ecr.stub_responses(:list_images, image_ids: [
                  {image_tag: "latest", image_digest: '0x789'},
                  {image_tag: tag, image_digest: digest},
                  {image_tag: '1tag', image_digest: '0x321'},
              ])

              expect(ecs).to receive(:describe_services).with(services: [name], cluster: cluster).and_call_original
              expect(ecs).to receive(:describe_task_definition).with(task_definition: td_arn).and_call_original
              expect(ecr).to receive(:list_images).with(repository_name: name, filter: {tag_status: "TAGGED"}, max_results: 1000).and_call_original

              result = manager.list_image_tags(cluster, name)
              expect(result).to be_a(Hash)
              expect(result[:latest]).to eq("latest")
            end

          end

        end

      end
    end
  end
end
