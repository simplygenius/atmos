require 'atmos'

module Atmos
  class ProviderFactory
    include GemLogger::LoggerSupport

    def self.get(name)
      @provider ||= begin
        logger.debug("Loading provider: #{name}")
        require "atmos/providers/#{name}/provider"
        provider = "Atmos::Providers::#{name.camelize}::Provider".constantize
        logger.debug("Loaded provider #{provider}")
        provider.new(name)
      end
      return @provider
    end

  end
end
