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

          describe "pull" do

            it "pulls latest image from repo" do
              ecr = ::Aws::ECR::Client.new
              expect(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              name = "myname"
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
                  with("docker", "pull", "#{repo}:latest").ordered

              result = manager.pull(name, revision: nil)
              expect(result[:remote_image]).to eq("#{repo}:latest")
            end

            it "pulls versioned image from repo" do
              ecr = ::Aws::ECR::Client.new
              expect(::Aws::ECR::Client).to receive(:new).and_return(ecr)

              name = "myname"
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
                  with("docker", "pull", "#{repo}:rev").ordered

              result = manager.pull(name, revision: "rev")
              expect(result[:remote_image]).to eq("#{repo}:rev")
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

          describe "run_task" do

            it "runs a service task" do
              ecs = ::Aws::ECS::Client.new
              expect(::Aws::ECS::Client).to receive(:new).and_return(ecs)
              expect(::Aws::CloudWatchLogs::Client).to_not receive(:new)

              cluster = "mycluster"
              name = "myname"
              command = ["do", "it"]
              task_id = "abc123"
              task_arn = "arn:aws:ecs:us-east-1:<aws_account_id>:task/#{task_id}"

              svc_stub = ecs.stub_data(:create_service).service
              defn_stub = ecs.stub_data(:describe_task_definition).task_definition
              defn_stub.compatibilities = [svc_stub.launch_type]
              defn_stub.container_definitions = [{}]

              ecs.stub_responses(:describe_services, services: [svc_stub.to_h])
              ecs.stub_responses(:describe_task_definition, task_definition: defn_stub.to_h)
              ecs.stub_responses(:run_task, tasks: [{task_arn: task_arn}])
              expect(ecs).to receive(:wait_until).with(:tasks_running, cluster: cluster, tasks: [task_id])

              result = manager.run_task(cluster, name, command: command, launch_type: svc_stub.launch_type)
              expect(result[:task_id]).to eq(task_id)
            end

            it "runs a non-service task" do
              ecs = ::Aws::ECS::Client.new
              expect(::Aws::ECS::Client).to receive(:new).and_return(ecs)
              expect(::Aws::CloudWatchLogs::Client).to_not receive(:new)

              cluster = "mycluster"
              name = "myname"
              command = ["do", "it"]
              task_id = "abc123"
              task_arn = "arn:aws:ecs:us-east-1:<aws_account_id>:task/#{task_id}"
              launch_type = "FARGATE"

              defn_stub = ecs.stub_data(:describe_task_definition).task_definition
              defn_stub.compatibilities = [launch_type]
              defn_stub.container_definitions = [{}]

              ecs.stub_responses(:describe_services)
              ecs.stub_responses(:list_task_definitions, task_definition_arns: [defn_stub.task_definition_arn])
              ecs.stub_responses(:describe_task_definition, task_definition: defn_stub.to_h)
              ecs.stub_responses(:run_task, tasks: [{task_arn: task_arn}])
              expect(ecs).to receive(:wait_until).with(:tasks_running, cluster: cluster, tasks: [task_id])

              result = manager.run_task(cluster, name, command: command, launch_type: launch_type)
              expect(result[:task_id]).to eq(task_id)
            end

            it "waits for logs when running a task" do
              ecs = ::Aws::ECS::Client.new
              expect(::Aws::ECS::Client).to receive(:new).and_return(ecs)
              cwl = ::Aws::CloudWatchLogs::Client.new
              expect(::Aws::CloudWatchLogs::Client).to receive(:new).and_return(cwl)

              cluster = "mycluster"
              name = "myname"
              command = ["do", "it"]
              task_id = "abc123"
              task_arn = "arn:aws:ecs:us-east-1:<aws_account_id>:task/#{task_id}"

              svc_stub = ecs.stub_data(:create_service).service
              defn_stub = ecs.stub_data(:describe_task_definition).task_definition
              defn_stub.compatibilities = [svc_stub.launch_type]
              defn_stub.container_definitions = [{log_configuration: {log_driver: "awslogs", options: {"awslogs-group" => "mygroup"}}}]
              log_stub = cwl.stub_data(:get_log_events)
              log_stub.events = [{timestamp: Time.now.to_i, message: "my log message"}]

              ecs.stub_responses(:describe_services, services: [svc_stub.to_h])
              ecs.stub_responses(:describe_task_definition, task_definition: defn_stub.to_h)
              ecs.stub_responses(:run_task, tasks: [{task_arn: task_arn}])
              expect(ecs).to receive(:wait_until).with(:tasks_running, cluster: cluster, tasks: [task_id])
              cwl.stub_responses(:get_log_events, **log_stub)

              result = manager.run_task(cluster, name, command: command, waiter_log_pattern: "my", launch_type: svc_stub.launch_type)
              expect(result[:task_id]).to eq(task_id)
              expect(result[:log_match]).to be_a_kind_of(MatchData)
            end

          end

          describe "wait" do

            it "waits for steady state for a service" do
              ecs = ::Aws::ECS::Client.new
              expect(::Aws::ECS::Client).to receive(:new).and_return(ecs)

              cluster = "mycluster"
              service = "myname"

              manager.wait(cluster, service)

              expect(ecs.api_requests.size).to eq(1)
              req = ecs.api_requests.first
              expect(req[:operation_name]).to eq(:describe_services)
              expect(req[:params][:cluster]).to eq(cluster)
              expect(req[:params][:services]).to eq([service])
            end

            it "waits for steady state for a task" do
              ecs = ::Aws::ECS::Client.new(stub_responses: true)
              expect(::Aws::ECS::Client).to receive(:new).and_return(ecs)

              cluster = "mycluster"
              task_id = "abc123"
              task_arn = "arn:aws:ecs:us-east-1:<aws_account_id>:task/#{task_id}"

              # Using a rspec stub as aws stubbing just blocks here for tasks, but services above seem to be ok
              expect(ecs).to receive(:wait_until).with(:tasks_running, cluster: cluster, tasks: [task_arn])
              manager.wait(cluster, task_arn)
            end

          end

          describe "stop_task" do

            it "stops a task" do
              ecs = ::Aws::ECS::Client.new
              allow(::Aws::ECS::Client).to receive(:new).and_return(ecs)

              ecs.stub_responses(:stop_task)
              result = manager.stop_task("mycluster", "abc123")
              expect(ecs.api_requests.size).to eq(1)
              expect(ecs.api_requests.first[:params][:cluster]).to eq("mycluster")
              expect(ecs.api_requests.first[:params][:task]).to eq("abc123")
            end

          end

        end

      end
    end
  end
end
