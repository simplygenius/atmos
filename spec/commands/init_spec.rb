require "simplygenius/atmos/commands/init"

module SimplyGenius
  module Atmos
    module Commands

      describe Init do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "execute" do

          it "calls terraform" do
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te)
            expect(te).to receive(:run).with("init", get_modules: false)
            cli.run([])
          end

        end

        describe "shared_plugin_dir" do

          it "copies plugins to user shared plugin dir if enabled" do
            within_construct do |c|
              c.file('config/atmos.yml')

              Atmos.config = Config.new("ops")

              env = Hash.new
              te = TerraformExecutor.new(env)
              expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
              expect(TerraformExecutor).to receive(:new).
                  with(process_env: env).and_return(te)
              expect(te).to receive(:run).with("init", get_modules: false)
              expect(cli).to receive(:mkdir_p).with(/.terraform.d\/plugins/)
              cli.run([])
            end
          end

          it "doesn't copy plugins to user shared plugin dir if disabled" do
            within_construct do |c|
              c.file('config/atmos.yml', YAML.dump("atmos" => {"terraform" => {"disable_shared_plugins" => true}}))

              Atmos.config = Config.new("ops")

              env = Hash.new
              te = TerraformExecutor.new(env)
              expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
              expect(TerraformExecutor).to receive(:new).
                  with(process_env: env).and_return(te)
              expect(te).to receive(:run).with("init", get_modules: false)
              expect(cli).to receive(:mkdir_p).with(/.terraform.d\/plugins/).never
              cli.run([])
            end
          end

          end

      end

    end
  end
end
