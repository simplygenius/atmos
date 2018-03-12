require "atmos/commands/secret"

describe Atmos::Commands::Secret do

  let(:cli) { described_class.new("") }

  around(:each) do |ex|
    within_construct do |c|
      c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {}}}))
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

  describe "get" do

    it "produces help text under standard width" do
      expect(described_class.new("get").help).to be_line_width_for_cli
    end

    it "requires a key" do
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.secret_manager).to_not receive(:get)
      expect { cli.run(["get"]) }.to raise_error(Clamp::UsageError, /KEY.*no value provided/)
    end

    it "gets a secret" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos.config.provider.secret_manager).to receive(:get).
          with("foo").and_return("bar")
      cli.run(["get", "foo"])
      expect(Atmos::Logging.contents).to match(/Secret value.*foo.*bar/)
    end

  end

  describe "set" do

    it "produces help text under standard width" do
      expect(described_class.new("set").help).to be_line_width_for_cli
    end

    it "requires a key" do
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.secret_manager).to_not receive(:get)
      expect { cli.run(["set"]) }.to raise_error(Clamp::UsageError, /KEY.*no value provided/)
    end

    it "requires a value" do
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.secret_manager).to_not receive(:get)
      expect { cli.run(["set", "key"]) }.to raise_error(Clamp::UsageError, /VALUE.*no value provided/)
    end

    it "sets a secret" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos.config.provider.secret_manager).to receive(:set).
          with("foo", "bar")
      cli.run(["set", "foo", "bar"])
      expect(Atmos::Logging.contents).to match(/Secret set for foo/)
    end

  end

  describe "list" do

    it "produces help text under standard width" do
      expect(described_class.new("list").help).to be_line_width_for_cli
    end

    it "lists secret keys" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos.config.provider.secret_manager).to receive(:to_h).
          and_return("foo" => "bar")
      cli.run(["list"])
      expect(Atmos::Logging.contents).to include("Secret keys are:").and include("foo")
    end

  end

  describe "delete" do

    it "produces help text under standard width" do
      expect(described_class.new("delete").help).to be_line_width_for_cli
    end

    it "requires a key" do
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.secret_manager).to_not receive(:get)
      expect { cli.run(["delete"]) }.to raise_error(Clamp::UsageError, /KEY.*no value provided/)
    end

    it "deletes a secret" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos.config.provider.secret_manager).to receive(:get).
          with("foo").and_return("bar")
      expect(Atmos.config.provider.secret_manager).to receive(:delete).
          with("foo")
      cli.run(["delete", "foo"])
      expect(Atmos::Logging.contents).to match(/Deleted secret: foo=bar/)
    end

  end

end
