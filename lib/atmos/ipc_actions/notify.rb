require_relative '../../atmos'
require_relative '../../atmos/ui'

module Atmos
  module IpcActions
    class Notify
      include GemLogger::LoggerSupport
      include Atmos::UI

      def initialize()
      end

      def execute(**opts)

        result = {
            'stdout' => '',
            'success' => ''
        }

        return result if Atmos.config["ipc.notify.disable"].to_s == "true"
        return notify(**opts)

      end

    end
  end
end
