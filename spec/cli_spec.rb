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

        it "adds the default plugins" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to receive(:is_atmos_repo?).and_return(false)
          cli.run(['version'])
          expect(conf.plugin_manager.output_filters(:stdout, {}).filters.first).to be_a_kind_of(Plugins::PromptNotify)
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

      describe "executable" do

        it "runs the cli" do
          @c.file('config/atmos.yml')
          exe = File.expand_path('../../exe/atmos', __FILE__)
          gemfile = File.expand_path('../../Gemfile', __FILE__)
          Bundler.with_original_env do
            output, status = Open3.capture2e(ENV.to_h.merge("BUNDLE_GEMFILE" => gemfile), "bundle exec #{exe} version 2>&1")
            expect(status.exitstatus).to eq(0), "exe failed: #{output}"
            expect(output).to include(VERSION)
            expect(File.exist?('atmos.log')).to be true
            expect(File.read('atmos.log')).to include(VERSION)
          end
        end

      end

    end

  end
end
