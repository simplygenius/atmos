require "simplygenius/atmos/commands/apply"

module SimplyGenius
  module Atmos
    module Commands

      describe Apply do

        let(:cli) {described_class.new("")}

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "execute" do

          it "calls terraform with auto modules by default" do
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te)
            expect(te).to receive(:run).with("apply", get_modules: true)
            expect(cli.auto_init).to be_falsey
            cli.run([])
            expect(cli.auto_init).to be_truthy
          end

          it "calls terraform without auto modules if configured" do
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te)
            Atmos.config.instance_variable_get(:@config).notation_put("atmos.terraform.disable_auto_modules", true)
            expect(te).to receive(:run).with("apply", get_modules: false)
            expect(cli.auto_init).to be_falsey
            cli.run([])
            expect(cli.auto_init).to be_truthy
          end

        end

      end

    end
  end
end
