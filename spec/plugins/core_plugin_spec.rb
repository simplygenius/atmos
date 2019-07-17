require "simplygenius/atmos/plugins/core_plugin"
require "simplygenius/atmos/plugin_manager"

module SimplyGenius
  module Atmos
    module Plugins

      describe CorePlugin do

        let (:pm) { SimplyGenius::Atmos::PluginManager.new([])}

        describe "initialize" do

          it "registers filters by default" do
            described_class.new(pm, {})
            expect(pm.output_filters(:stdout, {}).filters).to include(a_kind_of(Plugins::PromptNotify))
            expect(pm.output_filters(:stderr, {}).filters).to include(a_kind_of(Plugins::LockDetection))
            expect(pm.output_filters(:stdout, {}).filters).to include(a_kind_of(Plugins::PlanSummary))
            expect(pm.output_filters(:stdout, {}).filters).to include(a_kind_of(Plugins::JsonDiff))
          end

          it "can disable prompt notify" do
            described_class.new(pm, {disable_prompt_notify: true})
            expect(pm.output_filters(:stdout, {}).filters).to_not include(a_kind_of(Plugins::PromptNotify))
          end

          it "can disable lock detection" do
            described_class.new(pm, {disable_lock_detection: true})
            expect(pm.output_filters(:stderr, {}).filters).to_not include(a_kind_of(Plugins::LockDetection))
          end

          it "can disable plan summary" do
            described_class.new(pm, {disable_plan_summary: true})
            expect(pm.output_filters(:stdout, {}).filters).to_not include(a_kind_of(Plugins::PlanSummary))
          end

          it "can disable json diff" do
            described_class.new(pm, {disable_json_diff: true})
            expect(pm.output_filters(:stdout, {}).filters).to_not include(a_kind_of(Plugins::JsonDiff))
          end

        end

      end

    end
  end
end
