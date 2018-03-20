require "atmos/ipc_actions/notify"
require 'open3'

describe Atmos::IpcActions::Notify do

  let(:action) { described_class.new() }

  around(:each) do |ex|
    Atmos.config = Atmos::Config.new("ops")
    Atmos.config.instance_variable_set(:@config, Atmos::SettingsHash.new)
    ex.run
    Atmos.config = nil
  end

  describe "platforms" do

    describe 'mac' do

      it "generates script with message only" do
        expect(OS).to receive(:mac?).and_return(true)
        expect(action).to receive(:run).with(
            "osascript", "-l", "JavaScript", "-e", /"howdy".*withTitle: "Atmos Notification"/m
        ).and_return({})
        action.execute(message: 'howdy')
      end

      it "generates script with title" do
        expect(OS).to receive(:mac?).and_return(true)
        expect(action).to receive(:run).with(
            "osascript", "-l", "JavaScript", "-e", /"howdy".*withTitle: "mytitle"/m
        ).and_return({})
        action.execute(message: 'howdy', title: 'mytitle')
      end

      it "generates script without modal" do
        expect(OS).to receive(:mac?).and_return(true)
        expect(action).to receive(:run).with(
            "osascript", "-l", "JavaScript", "-e", /app.displayNotification\(/
        ).and_return({})
        action.execute(message: 'howdy')
      end

      it "generates script with modal" do
        expect(OS).to receive(:mac?).and_return(true)
        expect(action).to receive(:run).with(
            "osascript", "-l", "JavaScript", "-e", /app.displayDialog\(/
        ).and_return({})
        action.execute(message: 'howdy', modal: true)
      end

    end

    describe 'linux' do

      it "generates script for linux" do
        expect(OS).to receive(:mac?).and_return(false)
        expect(OS).to receive(:linux?).and_return(true)
        expect(action).to receive(:run).with("notify-send", "mytitle", "howdy").and_return({})
        action.execute(message: 'howdy', title: 'mytitle')
      end

    end

    describe 'other' do

      it "uses logger when unsupported" do
        expect(OS).to receive(:mac?).and_return(false)
        expect(OS).to receive(:linux?).and_return(false)
        expect(action).to receive(:run).never
        action.execute(message: 'howdy', title: 'mytitle')
        expect(Atmos::Logging.contents).to match(/mytitle: howdy/)
      end

    end

    describe 'custom' do

      it "fails for non-array custom script" do
        expect(OS).to receive(:mac?).never
        expect(OS).to receive(:linux?).never
        Atmos.config.instance_variable_get(:@config).notation_put('ipc.notify.command', 'foo')

        expect(action).to receive(:run).never
        expect{action.execute(message: 'howdy', title: 'mytitle')}.to raise_error(ArgumentError, /must be a list/)
      end

      it "generates custom script" do
        expect(OS).to receive(:mac?).never
        expect(OS).to receive(:linux?).never
        config = Atmos.config.instance_variable_get(:@config)
        config.notation_put('ipc.notify.command', ['foo', '{{modal}}', '{{title}}: {{message}}'])

        expect(action).to receive(:run).with('foo', 'false', 'mytitle: howdy').and_return({})
        action.execute(message: 'howdy', title: 'mytitle')
      end

    end

  end

  describe "execute" do

    it "sends a message" do
      config = Atmos.config.instance_variable_get(:@config)
      config.notation_put('ipc.notify.command', ['echo', '{{title}}: {{message}}'])
      expect(action.execute(title: 'mytitle', message: 'howdy')).
          to match(hash_including('stdout' => "mytitle: howdy\n"))
    end

    it "reports command failure" do
      config = Atmos.config.instance_variable_get(:@config)
      config.notation_put('ipc.notify.command', ['ls', 'nothere'])
      expect(action.execute(title: 'mytitle', message: 'howdy')).
          to match(hash_including('error' => /Notification process failed/))
    end

    it "disables notifications when desired" do
      config = Atmos.config.instance_variable_get(:@config)
      config.notation_put('ipc.notify.disable', true)
      expect(action).to receive(:run).never
      action.execute(title: 'mytitle', message: 'howdy')
    end

    it "disables modal when desired" do
      config = Atmos.config.instance_variable_get(:@config)
      config.notation_put('ipc.notify.disable_modal', true)
      config.notation_put('ipc.notify.command', ['foo', '{{modal}}', '{{title}}: {{message}}'])

      expect(action).to receive(:run).with('foo', 'false', 'mytitle: howdy').and_return({})
      action.execute(title: 'mytitle', message: 'howdy', modal: true)
    end

  end

end
