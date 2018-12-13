require_relative '../../atmos'
require_relative '../../atmos/ui'

module SimplyGenius
  module Atmos
    module Plugins

      class OutputFilter
        include GemLogger::LoggerSupport
        include UI

        attr_reader :context

        def initialize(context)
          @context = context
        end

        def filter(data, flushing: false)
          raise "not implemented"
        end

        def close
        end

      end

    end
  end
end
