require "simplygenius/atmos/ipc_actions/notify"
require 'open3'

module SimplyGenius
  module Atmos
    module IpcActions

      describe Notify do

        let(:action) { described_class.new() }

        around(:each) do |ex|
          @config = SettingsHash.new
          Atmos.config = Config.new("ops")
          Atmos.config.instance_variable_set(:@config, @config)
          ex.run
          Atmos.config = nil
        end

        it "calls through to ui notify" do
          expect(action).to receive(:notify).
              with(message: "foo").and_return(hash_including(:stdout, :status))
          action.execute(message: "foo")
        end

        it "disables notifications when desired" do
          @config.notation_put('atmos.ipc.notify.disable', true)

          expect(action).to_not receive(:notify)
          action.execute(message: "foo")
        end

      end

    end
  end
end
