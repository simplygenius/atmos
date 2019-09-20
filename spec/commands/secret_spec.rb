require "simplygenius/atmos/commands/secret"

module SimplyGenius
  module Atmos
    module Commands

      describe Secret do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {}}}))
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "--help" do

          it "produces help text under standard width" do
            expect(cli.help).to be_line_width_for_cli
          end

        end

        describe "get" do

          it "produces help text under standard width" do
            expect(described_class.new("get").help).to be_line_width_for_cli
          end

          it "requires a key" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.secret_manager).to_not receive(:get)
            expect { cli.run(["get"]) }.to raise_error(Clamp::UsageError, /KEY.*no value provided/)
          end

          it "gets a secret" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.secret_manager).to receive(:get).
                with("foo").and_return("bar")
            expect { cli.run(["get", "foo"]) }.to output("bar\n").to_stdout
            expect(Logging.contents).to match(/Secret value for foo:\n/)
          end

        end

        describe "set" do

          it "produces help text under standard width" do
            expect(described_class.new("set").help).to be_line_width_for_cli
          end

          it "requires a key" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.secret_manager).to_not receive(:get)
            expect { cli.run(["set"]) }.to raise_error(Clamp::UsageError, /KEY.*no value provided/)
          end

          it "requires a value" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.secret_manager).to_not receive(:get)
            expect { cli.run(["set", "key"]) }.to raise_error(Clamp::UsageError, /VALUE.*no value provided/)
          end

          it "sets a secret" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.secret_manager).to receive(:set).
                with("foo", "bar", force: false)
            cli.run(["set", "foo", "bar"])
            expect(Logging.contents).to match(/Secret set for foo/)
          end

          it "force sets a secret" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.secret_manager).to receive(:set).
                with("foo", "bar", force: true)
            cli.run(["set", "--force", "foo", "bar"])
            expect(Logging.contents).to match(/Secret set for foo/)
          end

        end

        describe "list" do

          it "produces help text under standard width" do
            expect(described_class.new("list").help).to be_line_width_for_cli
          end

          it "lists secret keys" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.secret_manager).to receive(:to_h).
                and_return("foo" => "bar")
            cli.run(["list"])
            expect(Logging.contents).to include("Secret keys are:").and include("foo")
          end

        end

        describe "delete" do

          it "produces help text under standard width" do
            expect(described_class.new("delete").help).to be_line_width_for_cli
          end

          it "requires a key" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.secret_manager).to_not receive(:get)
            expect { cli.run(["delete"]) }.to raise_error(Clamp::UsageError, /KEY.*no value provided/)
          end

          it "deletes a secret" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(Atmos.config.provider.secret_manager).to receive(:get).
                with("foo").and_return("bar")
            expect(Atmos.config.provider.secret_manager).to receive(:delete).
                with("foo")
            cli.run(["delete", "foo"])
            expect(Logging.contents).to match(/Deleted secret: foo=bar/)
          end

        end

      end

    end
  end
end
