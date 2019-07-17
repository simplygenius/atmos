require 'tempfile'
require 'simplygenius/atmos/cli'

module SimplyGenius
  module Atmos
    describe CLI do

      let(:cli) { described_class.new("") }

      around(:each) do |ex|
        within_construct do |c|
          @c = c
          Atmos.config = nil
          ex.run
          Atmos.config = nil
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
          expect(Logging.contents).to include(VERSION)
        end

      end

      describe "config" do

        it "produces config dump" do
          cli.run(['config'])
          expect(Logging.contents).to match(/^atmos_env:/)
        end

      end

      describe "--atmos-env" do

        it "defaults atmos env" do
          cli.run(['config'])
          expect(Atmos.config.atmos_env).to eq('ops')
        end

        it "allows setting atmos env" do
          cli.run(['--atmos-env', 'dev', 'config'])
          expect(Atmos.config.atmos_env).to eq('dev')
        end

      end

      describe "--atmos-group" do

        it "defaults working group" do
          cli.run(['config'])
          expect(Atmos.config.working_group).to eq('default')
        end

        it "allows setting atmos working group" do
          cli.run(['--atmos-group', 'foo', 'config'])
          expect(Atmos.config.working_group).to eq('foo')
        end

      end

      describe "--debug" do

        it "defaults to info log level" do
          cli.run(['version'])
        end

        it "sets log level to debug" do
          expect(Logging).to receive(:setup_logging).with(true, any_args)
          cli.run(['--debug', 'version'])
        end

      end

      describe "logging" do

        it "defaults to writing to logfile if in atmos repo" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to receive(:is_atmos_repo?).and_return(true)
          expect(Logging).to receive(:setup_logging).with(any_args, 'atmos.log')
          cli.run(['version'])
        end

        it "defaults to no logfile if not atmos repo" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to receive(:is_atmos_repo?).and_return(false)
          expect(Logging).to receive(:setup_logging).with(any_args, nil)
          cli.run(['version'])
        end

        it "can disable writing to logfile" do
          expect(Logging).to receive(:setup_logging).with(any_args, nil)
          cli.run(['--no-log', 'version'])
        end

      end

      describe "plugins" do

        it "loads plugins" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to receive(:is_atmos_repo?).and_return(false)
          expect(conf.plugin_manager).to receive(:load_plugins).once
          cli.run(['version'])
        end

      end

      describe "--no-color" do

        it "defaults to color" do
          expect($stdout).to receive(:tty?).and_return(true)
          expect(Logging).to receive(:setup_logging).with(anything, true, anything)
          expect(UI).to receive(:color_enabled=).with(true)
          cli.run(['version'])
        end

        it "outputs plain text" do
          expect(Logging).to receive(:setup_logging).with(anything, false, anything)
          expect(UI).to receive(:color_enabled=).with(false)
          cli.run(['--no-color', 'version'])
        end

      end

      describe "--load-path" do

        it "defaults to none" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to receive(:add_user_load_path).with(no_args)
          cli.run(['version'])
        end

        it "passes paths to config" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to receive(:add_user_load_path).with("foo", "bar")
          cli.run(['--load-path', 'foo', '--load-path', 'bar', 'version'])
        end

      end

    end

  end
end
