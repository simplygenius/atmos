require 'atmos/logging'
require 'rainbow'

describe Atmos::Logging do

  describe "setup_logging" do

  end

  describe Atmos::Logging::CaptureStream do

    let(:appender) {
      ::Logging.appenders.string_io('test')
    }

    before :all do
      @orig_rainbow = Rainbow.enabled
      Rainbow.enabled = true
    end

    after :all do
      Rainbow.enabled = @orig_rainbow
    end

    it "creates the logger with correct atrributes" do
      r, w = IO.pipe
      cs = described_class.new("myname", appender, w)
      logger = ::Logging.logger["myname"]
      expect(logger).to_not be_nil
      expect(logger.appenders).to eq([appender])
      expect(logger.additive).to eq(false)
    end

    it "passes writes to logger and destination" do
      r, w = IO.pipe
      cs = described_class.new("myname", appender, w)
      cs.write("hello")
      expect(r.readpartial(1024)).to eq("hello")
      expect(appender.sio.to_s).to match(/hello$/)
    end

    it "strips color from logger but not destination" do
      r, w = IO.pipe
      cs = described_class.new("myname", appender, w)
      cs.write(Rainbow("hello").green)
      expect(r.readpartial(1024)).to eq(Rainbow("hello").green)
      expect(appender.sio.to_s).to match(/hello$/)
    end

    it "adds color to destination if desired" do
      r, w = IO.pipe
      expect(w).to receive(:tty?).and_return(true)
      cs = described_class.new("myname", appender, w, :red)
      cs.write("hello")
      expect(r.readpartial(1024)).to eq(Rainbow("hello").red)
      expect(appender.sio.to_s).to match(/hello$/)
    end

    it "doesn't add color to destination if not tty" do
      r, w = IO.pipe
      expect(w).to receive(:tty?).and_return(false)
      cs = described_class.new("myname", appender, w, :red)
      cs.write("hello")
      expect(r.readpartial(1024)).to eq("hello")
      expect(appender.sio.to_s).to match(/hello$/)
    end

    it "handles multiple lines" do
       r, w = IO.pipe
       expect(w).to receive(:tty?).and_return(true)
       cs = described_class.new("myname", appender, w, :red)
       c = cs.write("hello\nthere\nfoo")
       output = "#{Rainbow("hello\n").red}#{Rainbow("there\n").red}#{Rainbow("foo").red}"
       expect(c).to eq(output.size)
       expect(r.readpartial(1024)).to eq(output)
       expect(appender.sio.to_s).to match(/hello\nthere\nfoo$/)
     end

  end

end
