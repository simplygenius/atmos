require 'tempfile'
require 'atmos/cli'

describe Atmos::CLI do

  let(:cli) { described_class.new("") }

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
      lines = cli.help.split("\n")
      lines.each {|l| expect(l.size).to be <= 80 }
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

  describe "--logfile" do

    it "defaults to stdout" do
      cli.run(['version'])
      expect(Atmos::Logging.contents).to include(Atmos::VERSION)
      cli.logger.info("infolog")
      expect(Atmos::Logging.contents).to include("infolog")
    end

    it "sets log to file" do
      file = Tempfile.new('cli_spec').path
      cli.run(argv(logfile: file) + ['version'])
      expect(Logging.logger.root.appenders.collect(&:name)).to eq([file])
      cli.logger.info("infolog")
      expect(open(file).read).to include("infolog")
    end

  end

  describe "--no-color" do

    it "defaults to color" do
      cli.run(['version'])
      expect(Logging.logger.root.appenders.first.layout.color_scheme).to_not be_nil
    end

    it "outputs plain text" do
      cli.run(['--no-color', 'version'])
      expect(Logging.logger.root.appenders.first.layout.color_scheme).to be_nil
    end

  end

  describe "executable" do

    it "runs the cli" do
      exe = File.expand_path('../../exe/atmos', __FILE__)
      output = `bundle exec #{exe} version`
      expect($?.exitstatus).to be(0)
      expect(output).to include(Atmos::VERSION)
    end

  end

end
