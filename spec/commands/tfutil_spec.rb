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
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(["so", "se", okstatus])
            expect{cli.run(["jsonify", *cmd])}.to output(JSON.generate(stdout: "so", stderr: "se", exitcode: "0") + "\n").to_stdout
          end

          it "parses stdin as json and makes it available for interpolation in the given command" do
            cmd = %w(foo #{bar})
            expect(Open3).to receive(:capture3).with("foo", "bum", any_args).and_return(["so", "se", okstatus])
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
              expect(Open3).to receive(:capture3).with("foo", "ops", any_args).and_return(["so", "se", okstatus])
              expect{cli.run(["jsonify", "-a", *cmd])}.to output.to_stdout
            ensure
              Atmos.config = nil
            end
          end

          it "provides command output within json" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(['{"hum":"dum"}', "", okstatus])
            expect{cli.run(["jsonify", *cmd])}.to output("{\"stdout\":\"{\\\"hum\\\":\\\"dum\\\"}\",\"stderr\":\"\",\"exitcode\":\"0\"}\n").to_stdout
          end

          it "provides command output as json" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(['{"hum":"dum"}', "", okstatus])
            expect{cli.run(["jsonify", "-j", *cmd])}.to output("{\"stdout\":\"{\\\"hum\\\":\\\"dum\\\"}\",\"stderr\":\"\",\"exitcode\":\"0\",\"hum\":\"dum\"}\n").to_stdout
          end

          it "flattens json command output" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(['{"hum":"dum", "boo": [1]}', "", okstatus])

            expect{cli.run(["jsonify", "-j", *cmd])}.to output(lambda{|o| j = JSON.parse(o); expect(j["boo"]).to eq("[\"1\"]") }).to_stdout
          end

          it "flattens non-hash json command output" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(['[1, 2]', "", okstatus])

            expect{cli.run(["jsonify", "-j", *cmd])}.to output(lambda{|o| j = JSON.parse(o); expect(j["data"]).to eq("[\"1\",\"2\"]") }).to_stdout
          end

          it "exits on error by default" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(["cmd", "bad", failstatus])
            expect{cli.run(["jsonify", *cmd])}.to output.to_stderr.and raise_error(SystemExit)
          end

          it "disables exits on error" do
            cmd = %w(foo bar)
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(["", "", failstatus])
            expect{cli.run(["jsonify", "--no-exit", *cmd])}.to output.to_stdout
          end

          it "can copy command to clipboard" do
            cmd = %w(foo bar)
            expect(Clipboard).to receive(:copy).with("'foo' 'bar'")
            expect(Open3).to receive(:capture3).with(*cmd, any_args).and_return(["", "", okstatus])
            expect{cli.run(["jsonify", "-c", *cmd])}.to output.to_stdout
          end

        end

        describe "terraform external constraints" do

          it "outputs terraform friendly json" do
            skip("test is for newer terraform only") if `terraform version` =~ /0.11/

            within_construct do |c|
              c.file('config/atmos.yml', "")
              c.file('test.tf', <<~EOF
                data "external" "test" {
                  program = [
                    "atmos", "tfutil", "jsonify", "-j",
                    "bash",
                    "-c",
                    "echo [1]"
                  ]
                }
                output "test" {
                  value = data.external.test.result
                }
                output "test_data" {
                  value = data.external.test.result.data
                }
              EOF
              )

              terraform "init"
              output = terraform "apply", "-auto-approve"
              expect(output).to match(/Outputs:\n\ntest = .*test_data = /m)
            end
          end

        end

      end

    end
  end
end
