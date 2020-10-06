require_relative '../atmos'

module SimplyGenius
  module Atmos

    class ProviderFactory
      include GemLogger::LoggerSupport

      def self.get(name)
        @providers ||= {}
        provider = @providers[name] ||= begin
          logger.debug("Loading provider: #{name}")
          require "simplygenius/atmos/providers/#{name}/provider"
          provider_class = "SimplyGenius::Atmos::Providers::#{name.camelize}::Provider".constantize
          logger.debug("Loaded provider #{provider_class}")
          provider_class.new(name)
        end
        return provider
      end

    end

  end
end
