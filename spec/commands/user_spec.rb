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
      manager = Atmos.config.provider.user_manager
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(manager).to receive(:create_user).
          with("foo@bar.com").and_return(user_name: "foo@bar.com")
      expect(manager).to_not receive(:set_groups)
      expect(manager).to_not receive(:enable_login)
      expect(manager).to_not receive(:enable_mfa)
      expect(manager).to_not receive(:enable_access_keys)
      expect(manager).to_not receive(:set_public_key)
      cli.run(["create", "foo@bar.com"])
    end

    it "require a username to be an email" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
      expect(Atmos.config.provider.user_manager).to_not receive(:create_user)
      expect { cli.run(["create", "foo"]) }.to raise_error(Clamp::UsageError, /USERNAME.*email/)
    end

    it "creates a user with all options" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)

      manager = Atmos.config.provider.user_manager
      expect(manager).to receive(:create_user).
          with("foo@bar.com").and_return(user_name: "foo@bar.com")
      expect(manager).to receive(:set_groups).
          with("foo@bar.com", ["g1", "g2"], force: false).and_return(groups: ["g1", "g2"])
      expect(manager).to receive(:enable_login).
          with("foo@bar.com", force: false).and_return(password: "sekret")
      expect(manager).to receive(:enable_mfa).
          with("foo@bar.com", force: false).and_return({})
      expect(manager).to receive(:enable_access_keys).
          with("foo@bar.com", force: false).and_return(key: "key", secret: "secret")
      expect(manager).to receive(:set_public_key).
          with("foo@bar.com", "mykey", force: false).and_return({})
      cli.run([
          "create",
          "--login", "--key", "--mfa", "--public-key", "mykey",
          "--group", "g1", "--group", "g2", "foo@bar.com"])
    end

    it "passes force to all modifiers" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)

      manager = Atmos.config.provider.user_manager
      expect(manager).to receive(:create_user).
          with("foo@bar.com").and_return(user_name: "foo@bar.com")
      expect(manager).to receive(:set_groups).
          with("foo@bar.com", ["g1", "g2"], force: true).and_return(groups: ["g1", "g2"])
      expect(manager).to receive(:enable_login).
          with("foo@bar.com", force: true).and_return(password: "sekret")
      expect(manager).to receive(:enable_mfa).
          with("foo@bar.com", force: true).and_return({})
      expect(manager).to receive(:enable_access_keys).
          with("foo@bar.com", force: true).and_return(key: "key", secret: "secret")
      expect(manager).to receive(:set_public_key).
          with("foo@bar.com", "mykey", force: true).and_return({})
      cli.run([
          "create", "--force",
          "--login", "--key", "--mfa", "--public-key", "mykey",
          "--group", "g1", "--group", "g2", "foo@bar.com"])
    end

    it "prompts for saving mfa secret" do
      env = Hash.new
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)

      manager = Atmos.config.provider.user_manager
      expect(manager).to receive(:create_user).
          with("foo@bar.com").and_return(user_name: "foo@bar.com")
      expect(manager).to receive(:enable_mfa).
          with("foo@bar.com", force: false).and_return(mfa_secret: "sekret")

      @otp = Atmos::Otp.send(:new)
      allow(Atmos::Otp).to receive(:instance).and_return(@otp)
      expect(@otp).to receive(:save)
      simulate_stdin("y") do
        expect{cli.run(["create", "--mfa", "foo@bar.com"])}.
            to output(/Save the MFA secret/).to_stdout
      end
    end

  end

end
