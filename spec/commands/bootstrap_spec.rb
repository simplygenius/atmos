require "simplygenius/atmos/commands/bootstrap"
require "simplygenius/atmos/terraform_executor"

module SimplyGenius
  module Atmos
    module Commands

      describe Bootstrap do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            @c = c
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops", "bootstrap")
            ex.run
            Atmos.config = nil
          end
        end

        describe "execute" do

          it "runs against a fresh repo" do
            env = Hash.new
            te = double(TerraformExecutor)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).
                with(ENV, bootstrap: true).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te)

            expect(te).to receive(:run).with("init", "-input=false", "-lock=false",
                              skip_backend: true, skip_secrets: true)
            expect(te).to receive(:run).with("apply", "-input=false",
                              skip_backend: true, skip_secrets: true)
            expect(te).to receive(:run).with("init", "-input=false", "-force-copy",
                              skip_secrets: true)

            te_norm = double(TerraformExecutor)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te_norm)

            expect(te_norm).to receive(:run).with("init", "-input=false",
                              skip_secrets: true)

            cli.run([])
          end

          it "aborts if already initialized" do
            expect(Atmos.config.tf_working_dir).to match(/\/bootstrap$/)
            @c.directory(File.join(Atmos.config.tf_working_dir, '.terraform'))
            expect { cli.run([]) }.to raise_error(Clamp::UsageError, /first/)
          end

          # TODO: full terraform integration test
        end

      end

    end
  end
end
