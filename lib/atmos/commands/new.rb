require 'atmos'
require 'clamp'
require 'atmos/commands/generate'

module Atmos::Commands

  class New < Atmos::Commands::Generate
    include GemLogger::LoggerSupport

    def self.description
      "Sets up a new atmos project in the current directory"
    end

    def execute
      template_list << "new"
      super
    end

  end

end
