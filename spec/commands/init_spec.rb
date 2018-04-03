require "atmos/commands/init"

describe Atmos::Commands::Init do

  let(:cli) { described_class.new("") }

  around(:each) do |ex|
    within_construct do |c|
      c.file('config/atmos.yml')
      Atmos.config = Atmos::Config.new("ops")
      ex.run
      Atmos.config = nil
    end
  end

  describe "execute" do

    it "calls terraform" do
      env = Hash.new
      te = Atmos::TerraformExecutor.new(env)
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos::TerraformExecutor).to receive(:new).
          with(process_env: env, working_group: 'default').and_return(te)
      expect(te).to receive(:run).with("init", get_modules: false)
      cli.run([])
    end

  end

end
