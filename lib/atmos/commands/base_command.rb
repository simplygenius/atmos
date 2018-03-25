require 'atmos'
require 'atmos/ui'
require 'clamp'

module Atmos::Commands

  class BaseCommand < Clamp::Command
    include GemLogger::LoggerSupport
    include Atmos::UI
  end

end
