require_relative '../../../atmos'

Dir.glob(File.join(__dir__, '*.rb')) do |f|
  require_relative "#{File.basename(f).sub(/\.rb$/, "")}"
end

module SimplyGenius
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
              AuthManager.new(self)
            end
          end

          def user_manager
            @user_manager ||= begin
              UserManager.new(self)
            end
          end

          def account_manager
            @account_manager ||= begin
              AccountManager.new(self)
            end
          end

          def secret_manager
            @secret_manager ||= begin
              conf = Atmos.config[:secret]
              logger.debug("Secrets config is: #{conf}")
              manager_type = conf[:type] || "ssm"
              if manager_type !~ /::/
                manager_type += "_secret_manager"
                manager_type = "#{self.class.name.deconstantize}::#{manager_type.camelize}"
              end
              manager = manager_type.constantize
              logger.debug("Using secrets manager #{manager}")
              manager.new(self)
            end
          end

          def container_manager
            @container_manager ||= begin
              ContainerManager.new(self)
            end
          end
        end

      end
    end
  end
end
