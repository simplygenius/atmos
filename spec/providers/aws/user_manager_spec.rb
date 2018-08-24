require 'simplygenius/atmos/providers/aws/user_manager'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe UserManager do

          let(:manager) { described_class.new(nil) }

          before(:all) do
            @orig_stub_responses = ::Aws.config[:stub_responses]
            ::Aws.config[:stub_responses] = true
          end

          after(:all) do
            ::Aws.config[:stub_responses] = @orig_stub_responses
          end

          after(:each) do
            ::Aws.config[:iam] = nil
          end

          describe "create_user" do

            it "creates a user" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:get_user)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(user: {user_name: 'foo@bar.com'})
              ::Aws.config[:iam] = {
                stub_responses: {
                  get_user: ['NoSuchEntity', stub]
                }
              }

              user = manager.create_user("foo@bar.com")
              expect(user).to match(hash_including(user_name: "foo@bar.com"))
              expect(Logging.contents).to match(/Creating new user/)
            end

            it "proceeds with existing user" do
              user = manager.create_user("foo@bar.com")
              expect(user).to match(hash_including(user_name: "foo@bar.com"))
              expect(Logging.contents).to match(/already exists/)
            end

          end

          describe "set_groups" do

            it "sets groups" do
              user = manager.set_groups("foo@bar.com", ["g1", "g2"])
              expect(user).to match(hash_including(groups: ["g1", "g2"]))
            end

            it "does nothing for no groups" do
              user = manager.set_groups("foo@bar.com", [])
              expect(user).to match(hash_including(groups: []))
            end

            it "adds a group" do
              client = ::Aws::IAM::Client.new
              group_stub = client.stub_data(:get_group)
              group_stub = SymbolizedMash.new(group_stub.to_h).deep_merge(group: {group_name: 'g1'})

              ::Aws.config[:iam] = {
                stub_responses: {
                  list_groups_for_user: {groups: [group_stub[:group]]}
                }
              }

              user = manager.set_groups("foo@bar.com", ["g2"], force: false)
              expect(user).to match(hash_including(groups: ["g1", "g2"]))
            end

            it "replaces group" do
              client = ::Aws::IAM::Client.new
              group_stub = client.stub_data(:get_group)
              group_stub = SymbolizedMash.new(group_stub.to_h).deep_merge(group: {group_name: 'g1'})

              ::Aws.config[:iam] = {
                stub_responses: {
                  list_groups_for_user: {groups: [group_stub[:group]]}
                }
              }

              user = manager.set_groups("foo@bar.com", ["g2"], force: true)
              expect(user).to match(hash_including(groups: ["g2"]))
            end

          end

          describe "enable_login" do

            it "enables login" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:get_login_profile)
              ::Aws.config[:iam] = {
                stub_responses: {
                    get_login_profile: ['NoSuchEntity', stub]
                }
              }


              user = manager.enable_login("foo@bar.com")
              expect(user).to match(hash_including(password: anything))
              expect(Logging.contents).to_not match(/already exists/)
              expect(Logging.contents).to match(/User login enabled/)
            end

            it "does nothing if exists and not force" do
              user = manager.enable_login("foo@bar.com")
              expect(user).to match(hash_not_including(:password))
              expect(Logging.contents).to match(/already exists/)
              expect(Logging.contents).to_not match(/Updated user/)
            end

            it "updates login if exists and force" do
              user = manager.enable_login("foo@bar.com", force: true)
              expect(user).to match(hash_including(password: anything))
              expect(Logging.contents).to match(/already exists/)
              expect(Logging.contents).to match(/Updated user/)
            end

          end

          describe "enable_mfa" do

            before(:each) do
              @otp = Otp.send(:new)
              allow(Otp).to receive(:instance).and_return(@otp)
            end

            around(:each) do |ex|
              Atmos.config = Config.new("ops")
              @config = SettingsHash.new
              @config[:org] = "myorg"
              Atmos.config.instance_variable_set(:@config, @config)

              ex.run
              Atmos.config = nil
            end

            it "enables mfa" do
              expect(@otp).to receive(:generate).with("foo@bar.com").and_return("123456")
              expect(manager).to receive(:sleep)
              expect(@otp).to receive(:generate).with("foo@bar.com").and_return("654321")

              user = manager.enable_mfa("foo@bar.com")
              expect(user).to match(hash_including(mfa_secret: anything))
              expect(Logging.contents).to_not match(/already exist/)
            end

            it "does nothing if exists and not force" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:create_virtual_mfa_device).virtual_mfa_device.to_h
              stub.merge!(user_name: "foo@bar.com").delete(:user)
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_mfa_devices: {mfa_devices: [stub]}
                }
              }

              user = manager.enable_mfa("foo@bar.com")
              expect(user).to match(hash_not_including(:mfa_secret))
              expect(Logging.contents).to match(/already exist/)
              expect(Logging.contents).to_not match(/Deleting old mfa devices/)
            end

            it "updates if exists and force" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:create_virtual_mfa_device).virtual_mfa_device.to_h
              stub.merge!(user_name: "foo@bar.com").delete(:user)
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_mfa_devices: {mfa_devices: [stub]}
                }
              }

              expect(@otp).to receive(:remove).with("foo@bar.com")
              expect(@otp).to receive(:generate).with("foo@bar.com").and_return("123456")
              expect(manager).to receive(:sleep)
              expect(@otp).to receive(:generate).with("foo@bar.com").and_return("654321")

              user = manager.enable_mfa("foo@bar.com", force: true)
              expect(user).to match(hash_including(mfa_secret: anything))
              expect(Logging.contents).to match(/Deleting old mfa devices/)
              expect(Logging.contents).to match(/already exist/)
            end

          end

          describe "enable_access_keys" do

            it "enables access keys" do
              user = manager.enable_access_keys("foo@bar.com")
              expect(user).to match(hash_including(key: anything, secret: anything))
              expect(Logging.contents).to_not match(/already exist/)
            end

            it "does nothing if exists and not force" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:create_access_key).access_key.to_h
              stub.delete(:secret_access_key)
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_access_keys: {access_key_metadata: [stub]}
                }
              }

              user = manager.enable_access_keys("foo@bar.com")
              expect(user).to match(hash_not_including(:key, :secret))
              expect(Logging.contents).to match(/already exist/)
            end

            it "updates if exists and force" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:create_access_key).access_key.to_h
              stub.delete(:secret_access_key)
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_access_keys: {access_key_metadata: [stub]}
                }
              }

              user = manager.enable_access_keys("foo@bar.com", force: true)
              expect(user).to match(hash_including(key: anything, secret: anything))
              expect(Logging.contents).to match(/Deleting old access keys/)
              expect(Logging.contents).to match(/already exist/)
            end

          end

          describe "set_public_key" do

            it "sets a ssh public key" do
              user = manager.set_public_key("foo@bar.com", "mykey")
              expect(Logging.contents).to_not match(/already exists/)
            end

            it "does nothing if exists and not force" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:upload_ssh_public_key).ssh_public_key.to_h
              stub.delete(:fingerprint); stub.delete(:ssh_public_key_body)
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_ssh_public_keys: {ssh_public_keys: [stub]}
                }
              }

              user = manager.set_public_key("foo@bar.com", "mykey")
              expect(Logging.contents).to match(/already exist/)
            end

            it "updates if exists and force" do
              client = ::Aws::IAM::Client.new
              stub = client.stub_data(:upload_ssh_public_key).ssh_public_key.to_h
              stub.delete(:fingerprint); stub.delete(:ssh_public_key_body)
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_ssh_public_keys: {ssh_public_keys: [stub]}
                }
              }

              user = manager.set_public_key("foo@bar.com", "mykey", force: true)
              expect(Logging.contents).to match(/Deleting old ssh public keys/)
              expect(Logging.contents).to match(/already exist/)
            end
          end


        end

      end
    end
  end
end
