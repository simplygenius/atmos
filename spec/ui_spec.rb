require 'simplygenius/atmos/ui'
require 'rainbow'

module SimplyGenius
  module Atmos

    describe UI do

      let(:ui_class) do
        Class.new do
          include UI
        end
      end

      let(:ui) do
        ui_class.new
      end

      before :all do
        @orig_rainbow = Rainbow.enabled
        Rainbow.enabled = true
      end

      after :all do
        Rainbow.enabled = @orig_rainbow
      end

      describe "say" do

        it "sends text to stdout" do
          expect { ui.say("foo") }.to output("foo\n").to_stdout
        end

      end

      describe "display" do

        it "pretties a map for display" do
          expect(ui.display("foo" => "bar", "baz" => "bum")).to eq("  foo: bar\n  baz: bum\n")
        end

        it "stringifies keys for display" do
          expect(ui.display(foo: "bar", baz: {bum: "boo"})).to eq("  foo: bar\n  baz:\n    bum: boo\n")
        end

      end

      describe "notify" do

        around(:each) do |ex|
          Atmos.config = Config.new("ops")
          Atmos.config.instance_variable_set(:@config, SettingsHash.new)
          ex.run
          Atmos.config = nil
        end

        describe "platforms" do

          describe 'mac' do

            it "generates script with message only" do
              expect(OS).to receive(:mac?).and_return(true)
              expect(ui).to receive(:run_ui_process).with(
                  "osascript", "-l", "JavaScript", "-e", /"howdy".*withTitle: "Atmos Notification"/m
              ).and_return({})
              ui.notify(message: 'howdy')
            end

            it "generates script with title" do
              expect(OS).to receive(:mac?).and_return(true)
              expect(ui).to receive(:run_ui_process).with(
                  "osascript", "-l", "JavaScript", "-e", /"howdy".*withTitle: "mytitle"/m
              ).and_return({})
              ui.notify(message: 'howdy', title: 'mytitle')
            end

            it "generates script without modal" do
              expect(OS).to receive(:mac?).and_return(true)
              expect(ui).to receive(:run_ui_process).with(
                  "osascript", "-l", "JavaScript", "-e", /app.displayNotification\(/
              ).and_return({})
              ui.notify(message: 'howdy')
            end

            it "generates script with modal" do
              expect(OS).to receive(:mac?).and_return(true)
              expect(ui).to receive(:run_ui_process).with(
                  "osascript", "-l", "JavaScript", "-e", /app.displayDialog\(/
              ).and_return({})
              ui.notify(message: 'howdy', modal: true)
            end

          end

          describe 'linux' do

            it "generates script for linux" do
              expect(OS).to receive(:mac?).and_return(false)
              expect(OS).to receive(:linux?).and_return(true)
              expect(File).to receive(:exist?).with("/.dockerenv").and_return(false)
              expect(ui).to receive(:run_ui_process).with("notify-send", "mytitle", "howdy").and_return({})
              ui.notify(message: 'howdy', title: 'mytitle')
            end

            it "uses logger for linux docker" do
              expect(OS).to receive(:mac?).and_return(false)
              expect(OS).to receive(:linux?).and_return(true)
              expect(File).to receive(:exist?).with("/.dockerenv").and_return(true)
              expect(ui).to receive(:run_ui_process).never
              ui.notify(message: 'howdy', title: 'mytitle')
              expect(Logging.contents).to match(/mytitle.*howdy/m)
            end

          end

          describe 'other' do

            it "uses inline logger when unsupported" do
              expect(OS).to receive(:mac?).and_return(false)
              expect(OS).to receive(:linux?).and_return(false)
              expect(ui).to receive(:run_ui_process).never
              ui.notify(message: 'howdy', title: 'mytitle')
              expect(Logging.contents).to match(/mytitle.*howdy/m)
              expect(Logging.contents).to match(/Notifications are unsupported/m)
            end

            it "uses inline logger when given option" do
              expect(ui).to receive(:run_ui_process).never

              expect(OS).to receive(:mac?).and_return(true)
              expect(OS).to receive(:linux?).and_return(false)

              ui.notify(message: 'howdy', title: 'mytitle', inline: true)
              expect(Logging.contents).to match(/mytitle.*howdy/m)
              expect(Logging.contents).to_not match(/Notifications are unsupported/m)
              Logging.clear
            end

            it "uses inline logger when forced" do
              config = Atmos.config.instance_variable_get(:@config)
              config.notation_put('ui.notify.force_inline', true)
              expect(ui).to receive(:run_ui_process).never

              expect(OS).to receive(:mac?).and_return(true, false, false)
              expect(OS).to receive(:linux?).and_return(false, true, false)

              ui.notify(message: 'howdy', title: 'mytitle')
              expect(Logging.contents).to match(/mytitle.*howdy/m)
              expect(Logging.contents).to_not match(/Notifications are unsupported/m)
              Logging.clear

              ui.notify(message: 'howdy', title: 'mytitle', inline: false)
              expect(Logging.contents).to match(/mytitle.*howdy/m)
              Logging.clear

              config.notation_put('ui.notify.command', ["foo"])
              ui.notify(message: 'howdy', title: 'mytitle')
              expect(Logging.contents).to match(/mytitle.*howdy/m)
              Logging.clear
            end

          end

          describe 'custom' do

            it "fails for non-array custom script" do
              expect(OS).to receive(:mac?).never
              expect(OS).to receive(:linux?).never
              Atmos.config.instance_variable_get(:@config).notation_put('ui.notify.command', 'foo')

              expect(ui).to receive(:run_ui_process).never
              expect{ui.notify(message: 'howdy', title: 'mytitle')}.to raise_error(ArgumentError, /must be a list/)
            end

            it "generates custom script" do
              expect(OS).to receive(:mac?).never
              expect(OS).to receive(:linux?).never
              config = Atmos.config.instance_variable_get(:@config)
              config.notation_put('ui.notify.command', ['foo', '{{modal}}', '{{title}}: {{message}}'])

              expect(ui).to receive(:run_ui_process).with('foo', 'false', 'mytitle: howdy').and_return({})
              ui.notify(message: 'howdy', title: 'mytitle')
            end

          end

        end

        describe "execution" do

          it "sends a message" do
            config = Atmos.config.instance_variable_get(:@config)
            config.notation_put('ui.notify.command', ['echo', '{{title}}: {{message}}'])
            expect(ui.notify(title: 'mytitle', message: 'howdy')).
                to match(hash_including('stdout' => "mytitle: howdy\n"))
          end

          it "reports command failure" do
            config = Atmos.config.instance_variable_get(:@config)
            config.notation_put('ui.notify.command', ['ls', 'nothere'])
            expect(ui.notify(title: 'mytitle', message: 'howdy')).
                to match(hash_including('error' => /Notification process failed/))
          end

          it "disables notifications when desired" do
            config = Atmos.config.instance_variable_get(:@config)
            config.notation_put('ui.notify.disable', true)
            expect(ui).to receive(:run_ui_process).never
            ui.notify(title: 'mytitle', message: 'howdy')
          end

          it "disables modal when desired" do
            config = Atmos.config.instance_variable_get(:@config)
            config.notation_put('ui.notify.disable_modal', true)
            config.notation_put('ui.notify.command', ['foo', '{{modal}}', '{{title}}: {{message}}'])

            expect(ui).to receive(:run_ui_process).with('foo', 'false', 'mytitle: howdy').and_return({})
            ui.notify(title: 'mytitle', message: 'howdy', modal: true)
          end

        end

      end

      describe "warn" do

        it "sends text to stdout" do
          expect { ui.warn.say("foo") }.to output(Rainbow("foo").yellow + "\n").to_stdout
        end

      end

      describe "error" do

        it "sends text to stdout" do
          expect { ui.error.say("foo") }.to output(Rainbow("foo").red + "\n").to_stdout
        end

      end

      describe "ask" do

        it "asks for input on stdout" do
          result = nil
          expect { simulate_stdin("bar") { result = ui.ask("foo") } }.to output("foo\n").to_stdout
          expect(result).to eq("bar")
        end

      end

      describe "agree" do

        it "asks for y/n input on stdout" do
          result = nil
          expect { simulate_stdin("y") { result = ui.agree("foo ") } }.to output("foo ").to_stdout
          expect(result).to eq(true)
        end

        it "asks for y/n input with default on stdout" do
          result = nil
          expect { simulate_stdin("y") { result = ui.agree("foo ") {|q| q.default = 'y' } } }.to output("foo |y| ").to_stdout
          expect(result).to eq(true)
        end

        it "asks for y/n input with validation on stdout" do
          result = nil
          expect { simulate_stdin("x", "n") { result = ui.agree("foo ") } }.to output(/foo Please enter.*/).to_stdout
          expect(result).to eq(false)
        end

      end

      describe "choose" do

        it "chooses from menu input on stdout" do
          result = nil
          expect { simulate_stdin("2") { result = ui.choose("foo", "bar") } }.to output("1. foo\n2. bar\n?  ").to_stdout
          expect(result).to eq("bar")
        end

      end

    end

  end
end
