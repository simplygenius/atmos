require_relative '../atmos'
require_relative 'plugin_base'
require_relative 'plugins/prompt_notify'

module SimplyGenius
  module Atmos

    class Plugin < PluginBase

      def initialize
        register_output_filter(:stdout, Plugins::PromptNotify)
      end

    end

  end
end
