require "simplygenius/atmos/commands/terraform"

module SimplyGenius
  module Atmos
    module Commands

      describe Terraform do

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

          it "calls terraform passing through options and args" do
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env, working_group: 'default').and_return(te)
            expect(te).to receive(:run).with('--help', 'foo', '--bar', get_modules: false)
            cli.run(['--help', 'foo', '--bar'])
          end

          it "calls terraform with working group" do
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env,working_group: "bootstrap").and_return(te)
            expect(te).to receive(:run).with('init', get_modules: false)
            cli.run(['--group', 'bootstrap', 'init'])
          end

        end

      end

    end
  end
end
