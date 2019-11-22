require "simplygenius/atmos/commands/auth_exec"

module SimplyGenius
  module Atmos
    module Commands

      describe AuthExec do

        let(:cli) { described_class.new("") }

        describe "execute" do
          around(:each) do |ex|
            within_construct do |c|
              c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {}}))
              Atmos.config = Config.new("ops")
              ex.run
              Atmos.config = nil
            end
          end

          it "runs the command with authenticated env" do
            env = {'foo' => 'bar'}
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).
                with(ENV, role: nil).and_yield(env)
            expect(cli).to receive(:system).with(env, "echo").and_return(true)
            cli.run(["echo"])
          end

          it "passes role to authenticate" do
            env = {'foo' => 'bar'}
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).
                with(ENV, role: 'myrole').and_yield(env)
            expect(cli).to receive(:system).with(env, "echo").and_return(true)
            cli.run(["--role", "myrole", "echo"])
          end

          it "succeeds for good command" do
            env = {'foo' => 'bar'}
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect { cli.run(["echo"]) }.to output.to_stdout_from_any_process
            expect(Logging.contents).to_not  match(/Process failed/)
          end

          it "handles cli error" do
            env = {'foo' => 'bar'}
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect { cli.run(["ls", "not"]) }.to output.to_stderr_from_any_process.and raise_error(SystemExit)
            expect(Logging.contents).to match(/Process failed/)
          end

          it "handles bad command" do
            env = {'foo' => 'bar'}
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect { cli.run(["notacmd"]) }.to raise_error(SystemExit)
            expect(Logging.contents).to match(/Process failed/)
          end

        end

      end

    end
  end
end
