require 'simplygenius/atmos/plugin'
require 'simplygenius/atmos/plugin_manager'

module SimplyGenius
  module Atmos

    describe Plugin do

      describe "config" do

        it "exposes config" do
          plugin = described_class.new(nil, {name: 'mine'})
          expect(plugin.config).to eq({name: 'mine'})
        end

      end

      describe "register_output_filter" do

        it "passes registration to manager" do
          config = Config.new("ops")
          allow(Atmos).to receive(:config).and_return(config)

          pm = instance_double("SimplyGenius::Atmos::PluginManager")
          plugin = described_class.new(pm, {})
          expect(pm).to receive(:register_output_filter).with(:stdout, Object)
          plugin.register_output_filter(:stdout, Object)
        end

      end

    end

  end
end
