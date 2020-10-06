require_relative '../../../atmos'

module SimplyGenius
  module Atmos
    module Providers
      module None

        class SecretManager
          include GemLogger::LoggerSupport

          def initialize(provider)
            @provider = provider
            @secrets = {}
          end

          def set(key, value, force: false)
            if @secrets.has_key?(key) && ! force
              raise "A value already exists for the given key, force overwrite or delete first"
            end
            @secrets[key] = value
          end

          def get(key)
            @secrets[key]
          end

          def delete(key)
            @secrets.delete(key)
          end

          def to_h
            @secrets.to_h
          end

        end

      end
    end
  end
end
