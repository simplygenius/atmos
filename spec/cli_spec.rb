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

      def all_usage(clazz, path=[])
        Enumerator.new do |y|
          obj = clazz.new("")
          path << clazz.name.split(":").last if path.empty?
          cmd_path = path.join(" -> ")
          y << {name: cmd_path, usage: obj.help}

          clazz.recognised_subcommands.each do |sc|
            sc_clazz = sc.subcommand_class
            sc_name = sc.names.first
            all_usage(sc_clazz, path + [sc_name]).each {|sy| y << sy}
          end
        end
      end

      describe "--help" do

        it "shows usage when no parameters" do
          expect { cli.run([]) }.to raise_exception(Clamp::HelpWanted)
        end

        it "produces help text under standard width" do
          all_usage(described_class).each do |m|
            expect(m[:usage]).to be_line_width_for_cli(m[:name])
          end
        end

      end

      describe "version" do

        it "produces version text" do
          cli.run(['version'])
          expect(Logging.contents).to include(VERSION)
        end

        it "uses flag to produce version text" do
          expect { cli.run(['-v']) }.to raise_error(SystemExit)
          expect(Logging.contents).to include(VERSION)
        end

      end

      describe "config" do

        it "produces config dump" do
          cli.run(['config'])
          expect(Logging.contents).to match(/^atmos_env:/)
        end

        it "produces json config dump" do
          cli.run(['config', '-j'])
          expect(Logging.contents).to match(/"atmos_env":/)
        end

        it "get specific string path" do
          Atmos.config = Config.new("ops")
          Atmos.config['foobar'] = 'baz'
          cli.run(['config', 'foobar'])
          expect(Logging.contents).to match(/baz/)
          expect(Logging.contents).to_not match(/foobar/)
        end

        it "get specific hash path" do
          Atmos.config = Config.new("ops")
          Atmos.config['foobar.baz'] = 'bum'
          cli.run(['config', 'foobar'])
          expect(Logging.contents).to match(/baz: bum/)
          expect(Logging.contents).to_not match(/foobar/)
          expect(Logging.contents).to_not match(/::/)
        end

        it "get specific array path" do
          Atmos.config = Config.new("ops")
          Atmos.config['foobar'] = ['bum']
          cli.run(['config', 'foobar'])
          expect(Logging.contents).to match(/- bum/)
          expect(Logging.contents).to_not match(/foobar/)
          expect(Logging.contents).to_not match(/::/)
        end

        it "get json for specific string path" do
          Atmos.config = Config.new("ops")
          Atmos.config['foobar'] = ['baz']
          cli.run(['config', '-j', 'foobar'])
          expect(Logging.contents).to match(/\[\s*"baz"\s*\]/m)
          expect(Logging.contents).to_not match(/foobar/)
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
          expect(Logging).to receive(:setup_logging).with(:debug, any_args)
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

      describe "--override" do

        it "defaults to none" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          expect(conf).to_not receive(:[]=)
          cli.run(['version'])
        end

        it "can override with a string" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          cli.run(['--override', 'foo=bar', 'version'])
          expect(conf["foo"]).to eq("bar")
        end

        it "can override with a number" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          cli.run(['--override', 'foo=3', 'version'])
          expect(conf["foo"]).to eq(3)
        end

        it "can override with an array" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          cli.run(['--override', 'foo=[x, y, z]', 'version'])
          expect(conf["foo"]).to eq(%w(x y z))
        end

        it "can override with a hash" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          cli.run(['--override', 'foo=[x, y, z]', 'version'])
          expect(conf["foo"]).to eq(%w(x y z))
        end

        it "overrides deep config" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          cli.run(['--override', 'foo.bar.baz=boo', 'version'])
          expect(conf["foo"]["bar"]["baz"]).to eq("boo")
        end

        it "overrides config non-additively" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          conf["foo.bar"] = [1, 2]
          expect(conf).to receive(:[]=).with("foo.bar", 3, additive: false).and_call_original
          cli.run(['--override', 'foo.bar=3', 'version'])
          expect(conf["foo"]["bar"]).to eq(3)
        end

        it "can override with an interpolated string" do
          conf = Config.new("ops")
          expect(Config).to receive(:new).and_return(conf)
          cli.run(['--override', 'foo="#{atmos_env}"', 'version'])
          expect(conf["foo"]).to eq("ops")
        end

      end

      describe "version requirement", :vcr do

        describe "#fetch_latest_ver" do

          it "fetches version from rubygems" do
            url = "https://rubygems.org/api/v1/versions/simplygenius-atmos/latest.json"
            stub_request(:get, url).to_return(body: JSON.dump(version: "0.11.11"))
            expect(cli.fetch_latest_version).to eq("0.11.11")
          end

          it "has an error string when version fails to fetch" do
            url = "https://rubygems.org/api/v1/versions/simplygenius-atmos/latest.json"
            expect(URI).to receive(:open).with(url).and_raise(RuntimeError, "bad")
            expect(cli.fetch_latest_version).to eq("[Version Fetch Failed]")
          end

        end

        describe "#version_check" do

          it "gets called by cli" do
            conf = Config.new("ops")
            expect(Config).to receive(:new).and_return(conf)
            expect(cli).to receive(:version_check).with(Atmos::VERSION)
            cli.run(['version'])
          end


          it "does nothing without config set" do
            Atmos.config = Config.new("ops")
            expect { cli.version_check(Atmos::VERSION) }.to_not raise_error
          end

          it "works for latest" do
            Atmos.config = Config.new("ops")
            Atmos.config["atmos.version_requirement"] = "latest"
            expect(cli).to receive(:fetch_latest_version).and_return("1.0.0", "0.0.1")
            expect { cli.version_check("0.0.1") }.to raise_error(RuntimeError, /The atmos version \(0.0.1\) does not match the given requirement \(latest: 1.0.0\)/)
            expect { cli.version_check("0.0.1") }.to_not raise_error
          end

          it "works for gem dependency form" do
            Atmos.config = Config.new("ops")
            Atmos.config["atmos.version_requirement"] = verspec = "~> 0.2.0"
            expect(cli).to_not receive(:fetch_latest_version)
            expect { cli.version_check("0.0.1") }.to raise_error(RuntimeError, /The atmos version \(0.0.1\) does not match the given requirement \(#{verspec}\)/)
            expect { cli.version_check("0.2.0") }.to_not raise_error
            expect { cli.version_check("0.2.1") }.to_not raise_error
            expect { cli.version_check("0.3.0") }.to raise_error(RuntimeError, /The atmos version \(0.3.0\) does not match the given requirement \(#{verspec}\)/)
          end

        end

      end

    end
  end
end
