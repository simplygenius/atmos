require "simplygenius/atmos/ipc_actions/ping"

module SimplyGenius
  module Atmos
    module IpcActions

      describe Ping do

        let(:action) { described_class.new() }

        describe "ping" do

          it "handles a message" do
            expect(action.execute(data: "foo")).to eq(data: "foo", action: "pong")
          end

        end

      end

    end
  end
end
