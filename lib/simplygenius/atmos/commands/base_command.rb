require_relative '../../atmos'
require_relative '../../atmos/ui'
require 'clamp'

module SimplyGenius
  module Atmos
    module Commands

      class BaseCommand < Clamp::Command
        include GemLogger::LoggerSupport
        include UI
      end

    end
  end
end
