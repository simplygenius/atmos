require 'atmos/ui'
require 'rainbow'

describe Atmos::UI do

  let(:ui_class) do
    Class.new do
      include Atmos::UI
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

end
