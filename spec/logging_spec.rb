require 'simplygenius/atmos/logging'
require 'rainbow'

module SimplyGenius
  module Atmos

    describe Logging do

      let(:logger) { ::Logging.logger.root }

      describe "setup_logging" do

        it "logs at info log level" do
          described_class.setup_logging(false, false, nil)
          logger.info("infolog")
          expect(Logging.contents).to include("infolog")
          logger.debug("debuglog")
          expect(Logging.contents).to_not include("debuglog")
        end

        it "logs at debug log level" do
          described_class.setup_logging(true, false, nil)
          logger.info("infolog")
          expect(Logging.contents).to include("infolog")
          logger.debug("debuglog")
          expect(Logging.contents).to include("debuglog")
        end

        it "can write to logfile" do
          within_construct do |c|
            expect(File.exist?('foo.log')).to be false
            described_class.setup_logging(false, false, 'foo.log')
            logger.info("howdy")
            expect(File.exist?('foo.log')).to be true
            expect(File.read('foo.log')).to include("howdy")
            expect(Logging.contents).to include("howdy")
          end
        end

        it "can avoid writing to logfile" do
          within_construct do |c|
            expect(File.exist?('foo.log')).to be false
            described_class.setup_logging(false, false, nil)
            logger.info("howdy")
            expect(File.exist?('foo.log')).to be false
            expect(Logging.contents).to include("howdy")
          end
        end

        it "logs with color" do
          described_class.setup_logging(false, true, nil)
          logger.info("howdy")
          a = ::Logging.logger.root.appenders.find {|a| a.try(:layout).try(:color_scheme) }
          expect(a).to_not be_nil
        end

        it "outputs plain text" do
          described_class.setup_logging(false, false, nil)
          a = ::Logging.logger.root.appenders.find {|a| a.try(:layout).try(:color_scheme) }
          expect(a).to be_nil
        end

      end

      describe Logging::CaptureStream do

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

  end
end
