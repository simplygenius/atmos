require_relative '../atmos'
require 'active_support/core_ext/class'

require_relative "plugins/output_filter"

module SimplyGenius
  module Atmos

    class Plugin
      include GemLogger::LoggerSupport

      attr_reader :plugin_manager, :config

      def initialize(plugin_manager, config)
        @plugin_manager = plugin_manager
        @config = config
      end

      def register_output_filter(type, clazz)
        plugin_manager.register_output_filter(type, clazz)
      end

    end

  end
end
