require_relative '../atmos'

module SimplyGenius
  module Atmos

    class ProviderFactory
      include GemLogger::LoggerSupport

      def self.get(name)
        @provider ||= begin
          logger.debug("Loading provider: #{name}")
          require "simplygenius/atmos/providers/#{name}/provider"
          provider = "SimplyGenius::Atmos::Providers::#{name.camelize}::Provider".constantize
          logger.debug("Loaded provider #{provider}")
          provider.new(name)
        end
        return @provider
      end

    end

  end
end
