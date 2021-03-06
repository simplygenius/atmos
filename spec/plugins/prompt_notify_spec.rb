require "simplygenius/atmos/plugins/prompt_notify"

module SimplyGenius
  module Atmos
    module Plugins

      describe PromptNotify do

        let(:plugin) { described_class.new({}) }

        it 'should notify if output matches' do
          expect(plugin).to receive(:notify)
          plugin.filter("Enter a value:")
        end

        it 'should not notify if output doesnt match' do
          expect(plugin).to_not receive(:notify)
          plugin.filter("Not value:")
        end

      end

    end
  end
end
