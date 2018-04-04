require_relative '../../atmos'
require 'open3'
require 'os'

module Atmos
  module IpcActions
    class Ping
      include GemLogger::LoggerSupport

      def initialize()
      end

      def execute(**opts)
        return opts.merge(action: 'pong')
      end

    end
  end
end
