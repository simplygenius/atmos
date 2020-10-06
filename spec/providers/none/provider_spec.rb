require 'simplygenius/atmos/providers/none/provider'

module SimplyGenius
  module Atmos
    module Providers
      module None

        describe Provider do

          let(:provider) { described_class.new("none") }

          describe "auth_manager" do

            it "gets the auth manager" do
              expect(provider.auth_manager).to be_instance_of(Providers::None::AuthManager)
            end

          end

          describe "user_manager" do

            it "is not implemented" do
              expect{provider.user_manager}.to raise_error(NotImplementedError)
            end

          end

          describe "account_manager" do

            it "is not implemented" do
              expect{provider.account_manager}.to raise_error(NotImplementedError)
            end

          end

          describe "secret_manager" do

            it "gets the auth manager" do
              expect(provider.secret_manager).to be_instance_of(Providers::None::SecretManager)
            end

          end

          describe "container_manager" do

            it "is not implemented" do
              expect{provider.container_manager}.to raise_error(NotImplementedError)
            end

          end

        end

      end
    end
  end
end
