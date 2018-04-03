require "atmos/commands/apply"

describe Atmos::Commands::Apply do

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

    it "calls terraform with auto modules by default" do
      env = Hash.new
      te = Atmos::TerraformExecutor.new(env)
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos::TerraformExecutor).to receive(:new).
          with(process_env: env, working_group: 'default').and_return(te)
      expect(te).to receive(:run).with("apply", get_modules: true)
      cli.run([])
    end

    it "calls terraform without auto modules if configured" do
      env = Hash.new
      te = Atmos::TerraformExecutor.new(env)
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos::TerraformExecutor).to receive(:new).
          with(process_env: env, working_group: 'default').and_return(te)
      Atmos.config.instance_variable_get(:@config)["disable_auto_modules"] = true
      expect(te).to receive(:run).with("apply", get_modules: false)
      cli.run([])
    end

  end

end
