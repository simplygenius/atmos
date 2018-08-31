require 'simplygenius/atmos/plugin'

module SimplyGenius
  module Atmos

    describe Plugin do

      describe "config" do

        it "exposes config" do
          plugin = described_class.new({name: 'mine'})
          expect(plugin.config).to eq({name: 'mine'})
        end

      end

      describe "register_output_filter" do

        it "passes registration to manager" do
          config = Config.new("ops")
          allow(Atmos).to receive(:config).and_return(config)

          plugin = described_class.new({})
          expect(Atmos.config.plugin_manager).to receive(:register_output_filter).with(:stdout, Object)
          plugin.register_output_filter(:stdout, Object)
        end

      end

    end

  end
end
