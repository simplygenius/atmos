require "simplygenius/atmos/commands/tfutil"

module SimplyGenius
  module Atmos
    module Commands

      describe TfUtil do

        let(:cli) { described_class.new("") }
        let(:okstatus) { double(Process::Status, exitstatus: 0) }
        let(:failstatus) { double(Process::Status, exitstatus: 1) }

        describe "jsonify" do

          it "runs the given command" do
            cmd = %w(foo bar)
            expect(Clipboard).to_not receive(:copy)
            expect(Open3).to receive(:capture3).with(*cmd, {}).and_return(["so", "se", okstatus])
            expect{cli.run(["jsonify", *cmd])}.to output(JSON.generate(stdout: "so", stderr: "se", exitcode: "0") + "\n").to_stdout
          end

          it "parses stdin as json and makes it available for interpolation in the given command" do
            cmd = %w(foo #{bar})
            expect(Open3).to receive(:capture3).with("foo", "bum", {}).and_return(["so", "se", okstatus])
            expect {
              simulate_stdin(JSON.generate(bar: "bum")) {
                cli.run(["jsonify", *cmd])
              }
            }.to output(JSON.generate(stdout: "so", stderr: "se", exitcode: "0") + "\n").to_stdout
          end

          it "extracts stdin key from json params and gives it as stdin to the command" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, stdin_data: "hello").and_return(["so", "se", okstatus])
            expect {
              simulate_stdin(JSON.generate(stdin: "hello")) {
                cli.run(["jsonify", *cmd])
              }
            }.to output(JSON.generate(stdout: "so", stderr: "se", exitcode: "0") + "\n").to_stdout
          end

          it "includes atmos config in params hash" do
            cmd = %w(foo #{atmos_env})
            begin
              Atmos.config = Config.new("ops")
              expect(Open3).to receive(:capture3).with("foo", "ops", {}).and_return(["so", "se", okstatus])
              expect{cli.run(["jsonify", "-a", *cmd])}.to output.to_stdout
            ensure
              Atmos.config = nil
            end
          end

          it "provides command output within json" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, {}).and_return(['{"hum":"dum"}', "", okstatus])
            expect{cli.run(["jsonify", *cmd])}.to output("{\"stdout\":\"{\\\"hum\\\":\\\"dum\\\"}\",\"stderr\":\"\",\"exitcode\":\"0\"}\n").to_stdout
          end

          it "provides command output as json" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, {}).and_return(['{"hum":"dum"}', "", okstatus])
            expect{cli.run(["jsonify", "-j", *cmd])}.to output("{\"stdout\":\"{\\\"hum\\\":\\\"dum\\\"}\",\"stderr\":\"\",\"exitcode\":\"0\",\"hum\":\"dum\"}\n").to_stdout
          end

          it "exits on error by default" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, {}).and_return(["", "", failstatus])
            expect{cli.run(["jsonify", *cmd])}.to raise_error(SystemExit)
          end

          it "disables exits on error" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, {}).and_return(["", "", failstatus])
            expect{cli.run(["jsonify", "--no-exit", *cmd])}.to output.to_stdout
          end

          it "can copy command to clipboard" do
            cmd = %w(foo bar)
            expect(Clipboard).to receive(:copy).with("'foo' 'bar'")
            expect(Open3).to receive(:capture3).with(*cmd, {}).and_return(["", "", okstatus])
            expect{cli.run(["jsonify", "-c", *cmd])}.to output.to_stdout
          end

        end

      end

    end
  end
end