require 'simplygenius/atmos/plugin'

module SimplyGenius
  module Atmos

    describe Plugin do

      describe "initialize" do

        it "registers built ins" do
          config = Config.new("ops")
          allow(Atmos).to receive(:config).and_return(config)

          plugin = described_class.new
          expect(config.plugin_manager.output_filters(:stdout, {}).filters.first).to be_a_kind_of(Plugins::PromptNotify)
        end

      end

    end

  end
end
