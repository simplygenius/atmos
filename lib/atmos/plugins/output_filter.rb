require_relative '../../atmos'
require_relative '../../atmos/ui'

module Atmos::Plugins
  class OutputFilter
    include GemLogger::LoggerSupport
    include Atmos::UI

    attr_reader :context

    def initialize(context)
      @context = context
    end

    def filter(data)
      raise "not implemented"
    end

    def close
    end

  end
end
