require 'simplygenius/atmos/providers/aws/account_manager'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe AccountManager do

          let(:manager) { described_class.new(nil) }

          before(:all) do
            @orig_stub_responses = ::Aws.config[:stub_responses]
            ::Aws.config[:stub_responses] = true
          end

          after(:all) do
            ::Aws.config[:stub_responses] = @orig_stub_responses
          end

          before(:each) do
            allow(manager).to receive(:sleep)
          end

          describe "create_account" do

            it "creates an account for existing org" do
              org = ::Aws::Organizations::Client.new
              expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
              expect(org).to_not receive(:create_organization)

              account = manager.create_account("dev")
              expect(account).to match(hash_including(:account_id))
            end

            it "creates an account for new org" do
              ::Aws.config[:organizations] = {
                stub_responses: {
                  describe_organization: 'AWSOrganizationsNotInUseException'
                }
              }

              org = ::Aws::Organizations::Client.new
              expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
              expect(org).to receive(:create_organization).and_call_original

              account = manager.create_account("dev")
              expect(account).to match(hash_including(:account_id))
            end

            it "creates an account with defaults" do
              client = ::Aws::Organizations::Client.new
              stub = client.stub_data(:describe_organization)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(organization: {master_account_email: 'foo@bar.com'})
              ::Aws.config[:organizations] = {
                stub_responses: {
                  describe_organization: stub
                }
              }

              org = ::Aws::Organizations::Client.new
              expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
              expect(org).to receive(:create_account).
                  with(email: "foo+dev@bar.com", account_name: "Atmos dev account").
                  and_call_original

              account = manager.create_account("dev")
              expect(account).to match(hash_including(email: "foo+dev@bar.com", name: "Atmos dev account"))
            end

            it "creates an account with givens" do
              org = ::Aws::Organizations::Client.new
              expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
              expect(org).to receive(:create_account).
                  with(email: "baz@bar.com", account_name: "myname").
                  and_call_original

              account = manager.create_account("dev", email:"baz@bar.com", name: "myname")
              expect(account).to match(hash_including(email: "baz@bar.com", name: "myname"))
            end

            it "creates an account with delayed status" do
              client = ::Aws::Organizations::Client.new
              stub = client.stub_data(:create_account)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(create_account_status: {state: 'in_progress'})
              ::Aws.config[:organizations] = {
                stub_responses: {
                    create_account: stub
                }
              }

              org = ::Aws::Organizations::Client.new
              expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
              expect(org).to receive(:describe_create_account_status).and_call_original

              account = manager.create_account("dev")
              expect(account).to match(hash_including(:account_id))
            end

            it "creates an account with failed status" do
              client = ::Aws::Organizations::Client.new
              stub = client.stub_data(:create_account)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(create_account_status: {state: 'failed'})
              ::Aws.config[:organizations] = {
                stub_responses: {
                    create_account: stub
                }
              }

              expect { manager.create_account("dev") }.to raise_error(SystemExit)
            end

          end

          describe "setup_credentials" do

            around :each do |ex|
              within_construct do |c|
                @c = c
                c.file('config/atmos.yml', YAML.dump({
                   org: "myorg",
                   region: "myregion",
                   auth: {
                      assume_role_name: "myrole"
                   },
                   environments: {
                       ops: {account_id: 123},
                       dev: {account_id: 456}
                   }
                 }))
                Atmos.config = Config.new("ops")

                RSpec::Mocks.with_temporary_scope do
                  expect(File).to receive(:expand_path).with("~/.aws/credentials").and_return("#{c}/conf/credentials").at_least(:once)
                  expect(File).to receive(:expand_path).with("~/.aws/config").and_return("#{c}/conf/config").at_least(:once)
                  allow(File).to receive(:expand_path).and_call_original

                  ex.run
                end

              end
            end

            it "creates dir/files if not present" do
              expect(File.exist?("#{@c}/conf/credentials")).to be false
              expect(File.exist?("#{@c}/conf/config")).to be false

              manager.setup_credentials(username: "foo@bar.com", access_key: "mykey", access_secret: "mysecret", become_default: false, force: false, nowrite: false)

              expect(File.exist?("#{@c}/conf/credentials")).to be true
              expect(File.exist?("#{@c}/conf/config")).to be true
            end

            it "does nothing for nowrite" do
              expect(File.exist?("#{@c}/conf/credentials")).to be false
              expect(File.exist?("#{@c}/conf/config")).to be false

              expect {
                manager.setup_credentials(username: "foo@bar.com", access_key: "mykey", access_secret: "mysecret", become_default: false, force: false, nowrite: true)
              }.to output.to_stdout

              expect(File.exist?("#{@c}/conf/credentials")).to be false
              expect(File.exist?("#{@c}/conf/config")).to be false
              expect(Logging.contents).to match(/Trial run only/)
            end

            it "adds profiles for each env" do
              manager.setup_credentials(username: "foo@bar.com", access_key: "mykey", access_secret: "mysecret", become_default: false, force: false, nowrite: false)

              creds = IniFile.load("#{@c}/conf/credentials")
              expect(creds.sections).to eq(["myorg"])
              expect(creds["myorg"]["aws_access_key_id"]).to eq("mykey")
              expect(creds["myorg"]["aws_secret_access_key"]).to eq("mysecret")
              expect(creds["myorg"]["mfa_serial"]).to eq("arn:aws:iam::123:mfa/foo@bar.com")

              config = IniFile.load("#{@c}/conf/config")
              expect(config.sections).to eq(["profile myorg", "profile myorg-ops", "profile myorg-dev"])
              expect(config["profile myorg"]["region"]).to eq("myregion")
              expect(config["profile myorg-ops"]["source_profile"]).to eq("myorg")
              expect(config["profile myorg-ops"]["role_arn"]).to eq("arn:aws:iam::123:role/myrole")
              expect(config["profile myorg-dev"]["source_profile"]).to eq("myorg")
              expect(config["profile myorg-dev"]["role_arn"]).to eq("arn:aws:iam::456:role/myrole")
            end

            it "sets default profile when desired" do
              manager.setup_credentials(username: "foo@bar.com", access_key: "mykey", access_secret: "mysecret", become_default: true, force: false, nowrite: false)

              creds = IniFile.load("#{@c}/conf/credentials")
              expect(creds.sections).to eq(["default"])

              config = IniFile.load("#{@c}/conf/config")
              expect(config.sections).to eq(["default", "profile myorg-ops", "profile myorg-dev"])
            end

            it "doesn't overwrite by default" do
              manager.setup_credentials(username: "foo@bar.com", access_key: "mykey", access_secret: "mysecret", become_default: false, force: false, nowrite: false)
              expect(Logging.contents).to_not match(/Skipping pre-existing sections/)
              orig_cred = File.read("#{@c}/conf/credentials")
              orig_config = File.read("#{@c}/conf/config")

              File.write("#{@c}/config/atmos.yml",
                         File.read("#{@c}/config/atmos.yml").
                             gsub!(/myrole/, "role2"))

              manager.setup_credentials(username: "foo@bar.com", access_key: "otherkey", access_secret: "mysecret", become_default: false, force: false, nowrite: false)
              expect(Logging.contents).to match(/Skipping pre-existing sections/)
              expect(File.read("#{@c}/conf/credentials")).to eq(orig_cred)
              expect(File.read("#{@c}/conf/config")).to eq(orig_config)
            end

            it "forces overwrite when desired" do
              manager.setup_credentials(username: "foo@bar.com", access_key: "mykey", access_secret: "mysecret", become_default: false, force: false, nowrite: false)
              expect(Logging.contents).to_not match(/Skipping pre-existing sections/)
              orig_cred = File.read("#{@c}/conf/credentials")
              orig_config = File.read("#{@c}/conf/config")

              File.write("#{@c}/config/atmos.yml",
                         File.read("#{@c}/config/atmos.yml").
                             gsub!(/myrole/, "role2"))

              manager.setup_credentials(username: "foo@bar.com", access_key: "otherkey", access_secret: "mysecret", become_default: false, force: true, nowrite: false)
              expect(Logging.contents).to_not match(/Skipping pre-existing sections/)
              expect(Logging.contents).to match(/Overwriting pre-existing sections/)
              expect(File.read("#{@c}/conf/credentials")).to_not eq(orig_cred)
              expect(File.read("#{@c}/conf/config")).to_not eq(orig_config)
            end

          end

        end

      end
    end
  end
end
