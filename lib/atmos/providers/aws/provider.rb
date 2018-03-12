require 'atmos'
require 'atmos/providers/aws/auth_manager'
require 'atmos/providers/aws/account_manager'
require 'atmos/providers/aws/user_manager'
require 'atmos/providers/aws/s3_secret_manager'

module Atmos
  module Providers
    module Aws

      class Provider
        include GemLogger::LoggerSupport

        def initialize(name)
          @name = name
        end

        def auth_manager
          @auth_manager ||= begin
            Atmos::Providers::Aws::AuthManager.new(self)
          end
        end

        def user_manager
          @user_manager ||= begin
            Atmos::Providers::Aws::UserManager.new(self)
          end
        end

        def account_manager
          @account_manager ||= begin
            Atmos::Providers::Aws::AccountManager.new(self)
          end
        end

        def secret_manager
          @secret_manager ||= begin
            Atmos::Providers::Aws::S3SecretManager.new(self)
          end
        end
      end

    end
  end
end
