require 'simplygenius/atmos/plugin_base'

module SimplyGenius
  module Atmos

    describe PluginBase do

      describe "register_output_filter" do

        it "passes registration to manager" do
          config = Config.new("ops")
          allow(Atmos).to receive(:config).and_return(config)

          plugin = described_class.new
          expect(Atmos.config.plugin_manager).to receive(:register_output_filter).with(:stdout, Object)
          plugin.register_output_filter(:stdout, Object)
        end

      end

    end

  end
end
