require_relative '../../../atmos'

module SimplyGenius
  module Atmos
    module Providers
      module None

        class AuthManager
          include GemLogger::LoggerSupport

          def initialize(provider)
            @provider = provider
          end

          def authenticate(system_env, **opts, &block)
            logger.debug("Calling none authentication target")
            block.call(system_env)
          end
        end

      end
    end
  end
end
