require 'gem_logger'
require 'clamp'
require 'atmos/commands/generate'

module Atmos::Commands

  class Init < Atmos::Commands::Generate #Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      "Initializes the repository"
    end

    def execute
      template_list << "init"
      super
    end

  end

end
