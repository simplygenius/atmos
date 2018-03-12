require 'tempfile'
require 'atmos/cli'

describe Atmos::CLI do

  let(:cli) { described_class.new("") }

  around(:each) do |ex|
    @orig_color = Atmos::UI.color_enabled
    Atmos::UI.color_enabled = false
    Atmos::Logging.setup_logging(false, false, nil)

    within_construct do |c|
      @c = c
      Atmos.config = nil
      ex.run
      Atmos::UI.color_enabled = @orig_color
      Atmos.config = nil
      Atmos::Logging.setup_logging(false, false, nil)
    end
  end

  def argv(arg)
    if arg.is_a?(Hash)
      arg.collect {|k, v| ["#{k =~ /^-/ ? k : "--#{k}"}", v]}.flatten
    elsif arg.is_a?(Enumerable)
      arg.each_slice(2).collect {|k, v| ["#{k =~ /^-/ ? k : "--#{k}"}", v]}.flatten
    else
      raise 'bad arg'
    end
  end

  describe "--help" do

    it "shows usage when no parameters" do
      expect { cli.run([]) }.to raise_exception(Clamp::HelpWanted)
    end

    it "produces help text under standard width" do
      expect(cli.help).to be_line_width_for_cli
    end

  end

  describe "version" do

    it "produces version text" do
      cli.run(['version'])
      expect(Atmos::Logging.contents).to include(Atmos::VERSION)
    end

  end

  describe "--debug" do

    it "defaults to info log level" do
      cli.run(['version'])
      expect(Atmos::Logging.contents).to include(Atmos::VERSION)
      cli.logger.debug("debuglog")
      expect(Atmos::Logging.contents).to_not include("debuglog")
      cli.logger.info("infolog")
      expect(Atmos::Logging.contents).to include("infolog")
    end

    it "sets log level to debug" do
      cli.run(['--debug', 'version'])
      expect(Atmos::Logging.contents).to include(Atmos::VERSION)
      cli.logger.debug("debuglog")
      expect(Atmos::Logging.contents).to include("debuglog")
      cli.logger.info("infolog")
      expect(Atmos::Logging.contents).to include("infolog")
    end

  end

  describe "logging" do

    it "defaults to stdout" do
      cli.run(['version'])
      expect(Atmos::Logging.contents).to include(Atmos::VERSION)
      cli.logger.info("infolog")
      expect(Atmos::Logging.contents).to include("infolog")
    end

    it "defaults to writing to logfile" do
      expect(File.exist?('atmos.log')).to be false
      cli.run(['version'])
      expect(File.exist?('atmos.log')).to be true
      expect(File.read('atmos.log')).to include(Atmos::VERSION)
    end

    it "can disable writing to logfile" do
      expect(File.exist?('atmos.log')).to be false
      cli.run(['--no-log', 'version'])
      expect(File.exist?('atmos.log')).to be false
    end

  end

  describe "--no-color" do

    it "defaults to color" do
      expect($stdout).to receive(:tty?).and_return(true)
      cli.run(['version'])
      expect(Atmos::UI.color_enabled).to be true
      a = ::Logging.logger.root.appenders.find {|a| a.try(:layout).try(:color_scheme) }
      expect(a).to_not be_nil
    end

    it "outputs plain text" do
      cli.run(['--no-color', 'version'])
      expect(Atmos::UI.color_enabled).to be false
      a = ::Logging.logger.root.appenders.find {|a| a.try(:layout).try(:color_scheme) }
      expect(a).to be_nil
    end

  end

  describe "executable" do

    it "runs the cli" do
      exe = File.expand_path('../../exe/atmos', __FILE__)
      output = `bundle exec #{exe} version`
      expect($?.exitstatus).to be(0)
      expect(output).to include(Atmos::VERSION)
      expect(File.exist?('atmos.log')).to be true
      expect(File.read('atmos.log')).to include(Atmos::VERSION)
    end

  end

end
