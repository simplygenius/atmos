require 'simplygenius/atmos/providers/aws/provider'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe Provider do

          let(:provider) { described_class.new("aws") }

          describe "auth_manager" do

            it "gets the auth manager" do
              expect(provider.auth_manager).to be_instance_of(Providers::Aws::AuthManager)
            end

          end

          describe "user_manager" do

            it "gets the user manager" do
              expect(provider.user_manager).to be_instance_of(Providers::Aws::UserManager)
            end

          end

          describe "account_manager" do

            it "gets the account manager" do
              expect(provider.account_manager).to be_instance_of(Providers::Aws::AccountManager)
            end

          end

          describe "secret_manager" do

            it "gets a ssm secret manager when nothing specified" do
              within_construct do |c|
                c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {}}}))
                Atmos.config = Config.new("ops")
                expect(provider.secret_manager).to be_instance_of(Providers::Aws::SsmSecretManager)
              end
            end

            it "gets a ssm secret manager when chosen" do
              within_construct do |c|
                c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {'type' => 'ssm'}}}))
                Atmos.config = Config.new("ops")
                expect(provider.secret_manager).to be_instance_of(Providers::Aws::SsmSecretManager)
              end
            end

            it "gets a s3 secret manager when chosen" do
              within_construct do |c|
                c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {'type' => 's3'}}}))
                Atmos.config = Config.new("ops")
                expect(provider.secret_manager).to be_instance_of(Providers::Aws::S3SecretManager)
              end
            end

            it "gets a custom secret manager when fully qualified" do
              FooSecretManager = Class.new do
                def initialize(p); end
              end
              name = FooSecretManager.name
              expect(name).to match(/::/)

              within_construct do |c|
                c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {'type' => name}}}))
                Atmos.config = Config.new("ops")
                expect(provider.secret_manager).to be_instance_of(Providers::Aws::FooSecretManager)
              end
            end

          end

          describe "container_manager" do

            it "gets the container manager" do
              expect(provider.container_manager).to be_instance_of(Providers::Aws::ContainerManager)
            end

          end


        end

      end
    end
  end
end
