require_relative '../../../atmos'

Dir.glob(File.join(__dir__, '*.rb')) do |f|
  require_relative "#{File.basename(f).sub(/\.rb$/, "")}"
end

module SimplyGenius
  module Atmos
    module Providers
      module None

        class Provider
          include GemLogger::LoggerSupport

          def initialize(name)
            @name = name
          end

          def auth_manager
            @auth_manager ||= begin
              AuthManager.new(self)
            end
          end

          def user_manager
            raise NotImplementedError.new("No user manager in none provider")
          end

          def account_manager
            raise NotImplementedError.new("No account manager in none provider")
          end

          def secret_manager
            @secret_manager ||= begin
              SecretManager.new(self)
            end
          end

          def container_manager
            raise NotImplementedError.new("No container manager in none provider")
          end
        end

      end
    end
  end
end
