require 'atmos/ipc'
require 'atmos/ipc_actions/ping'
require 'open3'

describe Atmos::Ipc do

  let(:ipc) { described_class.new() }

  describe "failure cases" do

    it "fails gracefully for empty messages" do
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts ""
          expect(JSON.parse(client.gets)).to match(hash_including("error"))
        end

      end
    end

    it "fails gracefully for bad messages" do
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts "[}"
          expect(JSON.parse(client.gets)).to match(hash_including("error"))
        end

      end
    end

    it "fails gracefully for an invalid action" do
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts JSON.generate(action: 'notanaction', data: 'foo')
          expect(JSON.parse(client.gets)).to match({"error" => /Unsupported ipc action/})
        end

      end
    end

    it "fails gracefully for a failing action" do
      action = Atmos::IpcActions::Ping.new
      expect(Atmos::IpcActions::Ping).to receive(:new).and_return(action)
      expect(action).to receive(:execute).and_raise("boom")

      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts JSON.generate(action: 'ping', data: 'foo')
          expect(JSON.parse(client.gets)).to match({"error" => /Failure while executing ipc action: boom/})
        end

      end
    end

    it "fails if run while running" do
      ipc.listen do |sock_path|
        expect{ipc.listen}.to raise_error(/Already listening/)
      end
    end

  end

  describe "basic usage" do

    it "succeeds for a good action" do
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts JSON.generate(action: 'ping', data: 'foo')
          expect(JSON.parse(client.gets)).to eq({"action" => "pong", "data" => "foo"})
        end

      end
    end

    it "cleans up for a second run" do
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts JSON.generate(action: 'ping', data: 'foo')
          expect(JSON.parse(client.gets)).to eq({"action" => "pong", "data" => "foo"})
        end

      end
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts JSON.generate(action: 'ping', data: 'foo')
          expect(JSON.parse(client.gets)).to eq({"action" => "pong", "data" => "foo"})
        end

      end
    end

    it "allows disabling" do
      ipc.listen do |sock_path|

        UNIXSocket.open(sock_path) do |client|
          client.puts JSON.generate(action: 'ping', data: 'foo', enabled: false)
          expect(JSON.parse(client.gets)).to match({"message" => /not enabled/})
        end

      end
    end

    it "produces a usable client script" do
      ipc.listen do |sock_path|
        script_path = ipc.generate_client_script
        input = JSON.generate(action: 'ping', data: 'foo')
        output, status = Open3.capture2(script_path, stdin_data: input)
        expect(status.success?).to be true
        expect(JSON.parse(output)).to eq({"action" => "pong", "data" => "foo"})
      end
    end

  end

end
