require "atmos/commands/container"

describe Atmos::Commands::Container do

  let(:cli) { described_class.new("") }

  around(:each) do |ex|
    within_construct do |c|
      c.file('config/atmos.yml')
      Atmos.config = Atmos::Config.new("ops")
      ex.run
      Atmos.config = nil
    end
  end

  describe "--help" do

    it "produces help text under standard width" do
      expect(cli.help).to be_line_width_for_cli
    end

  end

  describe "deploy" do

    it "produces help text under standard width" do
      expect(described_class.new("deploy").help).to be_line_width_for_cli
    end

    it "requires an cluster" do
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.container_manager).to_not receive(:push)
      expect { cli.run(["deploy"]) }.to raise_error(Clamp::UsageError, /'-c' is required/)
    end

    it "requires a name" do
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.container_manager).to_not receive(:push)
      expect { cli.run(["deploy", "-c", "foo"]) }.to raise_error(Clamp::UsageError, /NAME.*no value provided/)
    end

    it "deploys a service" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).
          to receive(:authenticate).with(ENV, role: nil).and_yield(env)
      expect(Atmos.config.provider.container_manager).
          to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
      expect(Atmos.config.provider.container_manager).
          to receive(:deploy_service).with("foo", "bar", "baz").and_return({})
      cli.run(["deploy", "-c", "foo", "bar"])
    end

    it "uses role when deploying a service" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).
          to receive(:authenticate).with(ENV, role: "myrole").and_yield(env)
      expect(Atmos.config.provider.container_manager).
          to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
      expect(Atmos.config.provider.container_manager).
          to receive(:deploy_service).with("foo", "bar", "baz").and_return({})
      cli.run(["deploy", "-r", "myrole", "-c", "foo", "bar"])
    end

    it "uses image when deploying a service" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).
          to receive(:authenticate).with(ENV, role: nil).and_yield(env)
      expect(Atmos.config.provider.container_manager).
          to receive(:push).with("bar", "myimage", revision: nil).and_return(remote_image: "baz")
      expect(Atmos.config.provider.container_manager).
          to receive(:deploy_service).with("foo", "bar", "baz").and_return({})
      cli.run(["deploy", "-i", "myimage", "-c", "foo", "bar"])
    end

    it "uses revision when deploying a service" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).
          to receive(:authenticate).with(ENV, role: nil).and_yield(env)
      expect(Atmos.config.provider.container_manager).
          to receive(:push).with("bar", "bar", revision: 'v123').and_return(remote_image: "baz")
      expect(Atmos.config.provider.container_manager).
          to receive(:deploy_service).with("foo", "bar", "baz").and_return({})
      cli.run(["deploy", "-v", "v123", "-c", "foo", "bar"])
    end

    it "deploys a task" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).
          to receive(:authenticate).with(ENV, role: nil).and_yield(env)
      expect(Atmos.config.provider.container_manager).
          to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
      expect(Atmos.config.provider.container_manager).
          to receive(:deploy_task).with("bar", "baz").and_return({})
      cli.run(["deploy", "-t", "-c", "foo", "bar"])
    end

  end

end
