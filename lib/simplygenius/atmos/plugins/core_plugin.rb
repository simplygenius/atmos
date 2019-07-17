require_relative '../../atmos'
require_relative "prompt_notify"
require_relative "lock_detection"
require_relative "plan_summary"
require_relative "json_diff"

module SimplyGenius
  module Atmos
    module Plugins

      class CorePlugin < SimplyGenius::Atmos::Plugin
        def initialize(plugin_manager, config)
          super
          register_output_filter(:stdout, Plugins::PromptNotify) unless config[:disable_prompt_notify]
          register_output_filter(:stderr, Plugins::LockDetection) unless config[:disable_lock_detection]
          register_output_filter(:stdout, Plugins::PlanSummary) unless config[:disable_plan_summary]
          register_output_filter(:stdout, Plugins::JsonDiff) unless config[:disable_json_diff]
        end
      end

    end
  end
end
