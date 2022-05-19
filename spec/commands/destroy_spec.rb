require "simplygenius/atmos/commands/destroy"

module SimplyGenius
  module Atmos
    module Commands

      describe Destroy do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "execute" do

          it "calls terraform" do
            env = Hash.new
            te = TerraformExecutor.new(process_env: env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te)
            expect(te).to receive(:run).with("destroy", get_modules: false)
            cli.run([])
            expect(cli.auto_init).to be_falsey
          end

        end

      end

    end
  end
end
