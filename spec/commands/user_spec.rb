require "atmos/commands/user"

describe Atmos::Commands::User do

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

  describe "create" do

    it "produces help text under standard width" do
      expect(described_class.new("create").help).to be_line_width_for_cli
    end

    it "requires a username" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.user_manager).to_not receive(:create_user)
      expect { cli.run(["create"]) }.to raise_error(Clamp::UsageError, /USERNAME.*no value provided/)
    end

    it "has defaults" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos.config.provider.user_manager).to receive(:create_user).
          with("foo@bar.com", ["all-users"],
               login: true, keys: false, public_key: nil)
      cli.run(["create", "foo@bar.com"])
    end

    it "require a username to be an email" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.user_manager).to_not receive(:create_user)
      expect { cli.run(["create", "foo"]) }.to raise_error(Clamp::UsageError, /USERNAME.*email/)
    end

    it "creates a user" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)

      expect(Atmos.config.provider.user_manager).to receive(:create_user).
          with("foo@bar.com", ["g1", "g2"],
               login: true, keys: true, public_key: "mykey")
      cli.run([
          "create",
          "--login", "--key", "--public-key", "mykey",
          "--group", "g1", "--group", "g2", "foo@bar.com"])
    end

  end

  describe "groups" do

    it "produces help text under standard width" do
      expect(described_class.new("groups").help).to be_line_width_for_cli

    end

    it "requires a username" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.user_manager).to_not receive(:modify_groups)
      expect { cli.run(["groups", "--group", "g1"]) }.to raise_error(Clamp::UsageError, /USERNAME.*no value provided/)
    end

    it "requires a groups" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.user_manager).to_not receive(:modify_groups)
      expect { cli.run(["groups", "foo@bar.com"]) }.to raise_error(Clamp::UsageError, /'-g' is required/)
    end

    it "has defaults" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos.config.provider.user_manager).to receive(:modify_groups).
          with("foo@bar.com", ["g1"], add: be_falsey)
      cli.run(["groups", "--group", "g1", "foo@bar.com"])
    end

    it "modifys a user" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)

      expect(Atmos.config.provider.user_manager).to receive(:modify_groups).
          with("foo@bar.com", ["g1", "g2"],
               add: true)
      cli.run([
          "groups", "--add", "--group", "g1", "--group", "g2", "foo@bar.com"])
    end

  end

end
