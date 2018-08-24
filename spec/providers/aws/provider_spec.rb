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

            it "gets the secret manager" do
              within_construct do |c|
                c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {}}}))
                Atmos.config = Config.new("ops")
                expect(provider.secret_manager).to be_instance_of(Providers::Aws::S3SecretManager)
              end
            end

          end

        end

      end
    end
  end
end
