require "simplygenius/atmos/commands/account"

module SimplyGenius
  module Atmos
    module Commands

      describe Account do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('environments' => {'ops' => {'foo' => 'bar'}}))
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "create" do

          it "requires an env" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.account_manager).to_not receive(:create_account)
            expect { cli.run(["create"]) }.to raise_error(Clamp::UsageError, /ENV.*no value provided/)
          end

          it "fails for preexisting env" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.account_manager).to_not receive(:create_account)
            expect { cli.run(["create", "ops"]) }.to raise_error(Clamp::UsageError, /Env.*already present/)
          end

          it "can override name" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.account_manager).to receive(:create_account).
                with("dev", name: "joe", email: nil).and_return({account_id: 1234 })
            cli.run(["create", "--name", "joe", "dev"])
          end

          it "can override email" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.account_manager).to receive(:create_account).
                with("dev", name: nil, email: "foo@bar.com").and_return({account_id: 1234 })
            cli.run(["create", "--email", "foo@bar.com", "dev"])
          end

          it "creates a user with defaults" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.account_manager).to receive(:create_account).
                with("dev", name: nil, email: nil).and_return({account_id: 1234 })
            cli.run(["create", "dev"])
            conf = YAML.load_file('config/atmos.yml')
            expect(conf['environments']['dev']['account_id']).to eq('1234')
          end

          it "copies source env to create user" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.account_manager).to receive(:create_account).
                with("dev", name: nil, email: nil).and_return({account_id: 1234 })
            cli.run(["create", "--source-env", "ops", "dev"])
            conf = YAML.load_file('config/atmos.yml')
            expect(conf['environments']['dev']['foo']).to eq('bar')
          end

          it "fails for non-existant source env" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.account_manager).to_not receive(:create_account)
            expect { cli.run(["create", "--source-env", "foo", "dev"]) }.
                to raise_error(Clamp::UsageError, /Source env.*does not exist/)
          end

        end

        describe "create" do

          it "requires a user" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.account_manager).to_not receive(:setup_credentials)
            expect { cli.run(["setup_credentials"]) }.to raise_error(Clamp::UsageError, /option '-u' is required/)
          end

          it "prompts for a key, which is required" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.account_manager).to_not receive(:setup_credentials)

            simulate_stdin("") do
              without_partial_double_verification do
                allow($stdin).to receive(:echo=)
              end
              expect { cli.run(["setup_credentials", "-u", "foo@bar.com"]) }.to output.to_stdout.and raise_error(ArgumentError, /An access key is required/)
            end
          end

          it "prompts for a secret, which is required" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.account_manager).to_not receive(:setup_credentials)

            simulate_stdin("key\n") do
              without_partial_double_verification do
                allow($stdin).to receive(:echo=)
              end
              expect { cli.run(["setup_credentials", "-u", "foo@bar.com"]) }.to output.to_stdout.and raise_error(ArgumentError, /An access secret is required/)
            end
          end

          it "calls through to provider" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.account_manager).to receive(:setup_credentials)

            simulate_stdin("key\nsecret\n") do
              without_partial_double_verification do
                allow($stdin).to receive(:echo=)
              end
              expect { cli.run(["setup_credentials", "-u", "foo@bar.com"]) }.to output.to_stdout
            end
          end

        end

      end
    end
  end
end
