require 'simplygenius/atmos/config'
require 'climate_control'

# bug with list override
# #
# #
# #gpfoo: "bar"
# #gpbar: ["gpx", "gpy", "gpz"]
# #gpbaz:
# #  gphum: "dum"
# #  gpboo: "bah"
# #  gpblah: ["gpx", "gpy", "gpz"]
# #
# #
# #environments:
# #  production:
# #    "^gpbar": ["gpa", "gpb"]
# #    gpbaz:
# #      gpboo: "prodbah"
# #      gpbar: "proddum"
# #      "^gpblah": ["gpa", "gpb"]
module SimplyGenius
  module Atmos

    describe Config do

      let(:config) { described_class.new("ops") }
      let(:config_hash) { config.send(:load); config.instance_variable_get(:@config) }

      describe "initialize" do

        it "sets up accessors" do
          env = "ops"
          config = described_class.new(env)
          expect(config.atmos_env).to eq(env)
          expect(config.working_group).to eq('default')
          expect(config.root_dir).to eq(Dir.pwd)
          expect(config.config_file).to eq("#{Dir.pwd}/config/atmos.yml")
          expect(config.tmp_root).to eq("#{Dir.pwd}/tmp")
        end

        it "can get root from env" do
          env = "ops"
          within_construct do |c|
            myroot = "#{c}/root"
            ClimateControl.modify('ATMOS_ROOT' => myroot) do
              config = described_class.new(env)
              expect(config.root_dir).to eq(myroot)
              expect(config.tmp_root).to eq("#{myroot}/tmp")
            end
          end
        end

        it "can get config from env" do
          env = "ops"
          within_construct do |c|
            myconf = "/a.yml"
            ClimateControl.modify('ATMOS_CONFIG' => myconf) do
              config = described_class.new(env)
              expect(config.config_file).to eq(myconf)
            end
          end
        end

        it "can get config relative to root from env" do
          env = "ops"
          within_construct do |c|
            myroot = "#{c}/root"
            myconf = "c/a.yml"
            ClimateControl.modify('ATMOS_ROOT' => myroot, 'ATMOS_CONFIG' => myconf) do
              config = described_class.new(env)
              expect(config.config_file).to eq("#{myroot}/#{myconf}")
            end
          end
        end

      end

      describe "tmp_dir" do

        it "creates the dir" do
          within_construct do |c|
            expect(config.tmp_dir).to eq("#{config.tmp_root}/#{config.atmos_env}")
            expect(Dir.exist?(config.tmp_dir)).to be true
          end
        end

      end

      describe "auth_cache_dir" do

        it "creates the dir" do
          within_construct do |c|
            expect(config.auth_cache_dir).to eq("#{config.tmp_root}/#{config.atmos_env}/auth")
            expect(Dir.exist?(config.auth_cache_dir)).to be true
          end
        end

      end

      describe "tf_working_dir" do

        it "creates the dir" do
          within_construct do |c|
            expect(config.tf_working_dir).
                to eq("#{config.tmp_root}/#{config.atmos_env}/tf/default")
            expect(Dir.exist?(config.tf_working_dir)).to be true
          end
        end

        it "creates the dir with a group" do
          config = described_class.new('ops', 'bootstrap')
          within_construct do |c|
            expect(config.tf_working_dir).
                to eq("#{config.tmp_root}/#{config.atmos_env}/tf/bootstrap")
            expect(Dir.exist?(config.tf_working_dir)).to be true
          end
        end

      end

      describe "is_atmos_repo?" do

        it "is false when config file is not there" do
          within_construct do |c|
            expect(File.exist?('config/atmos.yml')).to be false
            expect(config.is_atmos_repo?).to be false
          end
        end

        it "is true when config file exists" do
          within_construct do |c|
            c.file('config/atmos.yml')
            expect(config.is_atmos_repo?).to be true
          end
        end

      end

      describe "to_h" do

        it "returns the hash" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar"))
            expect(config.to_h).to be_a_kind_of(Hash)
            expect(config.to_h["foo"]).to eq("bar")
          end
        end

      end

      describe "provider" do

        it "returns the provider" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(provider: "aws"))
            expect(config.provider).to be_instance_of(Providers::Aws::Provider)
          end
        end

      end

      describe "plugin_manager" do

        it "returns the plugin manager" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            expect(config.plugin_manager).to be_instance_of(PluginManager)
          end
        end

      end

      describe "all_env_names" do

        it "returns the list of all env names" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(environments: {
                ops: {account_id: 123},
                dev: {account_id: 456}
            }))
            expect(config.all_env_names).to eq(["ops", "dev"])
          end
        end

      end

      describe "account_hash" do

        it "returns the hash of all accounts" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(environments: {
                ops: {account_id: 123},
                dev: {account_id: 456}
            }))
            expect(config.account_hash).to eq("ops" => 123, "dev" => 456)
          end
        end

      end

      describe "[]" do

        it "loads config and looks up key" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar"))
            expect(config["foo"]).to eq("bar")
          end
        end

        it "handles hash dot notation in keys" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: {bar: "baz"}))
            expect(config["foo.bar"]).to eq("baz")
          end
        end

      end

      describe "load_config_sources" do

        it "does nothing if no sources" do
          within_construct do |c|
            conf = SettingsHash.new
            result = config.send(:load_config_sources, "", conf)
            expect(result).to be conf
          end
        end

        it "loads from single relative pattern" do
          within_construct do |c|
            c.file('config/atmos/foo.yml', YAML.dump(foo: "baz"))
            c.file('config/atmos/bar.yml', YAML.dump(bar: "bum"))
            conf = SettingsHash.new
            result = config.send(:load_config_sources, "#{c}/config", conf, "atmos/*.yml")
            expect(result).to_not be conf
            expect(result["foo"]).to eq("baz")
            expect(result["bar"]).to eq("bum")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/config/atmos/foo.yml", "#{c}/config/atmos/bar.yml"])
          end
        end

        it "loads from single absolute pattern" do
          within_construct do |c|
            c.file('atmos/foo.yml', YAML.dump(foo: "baz"))
            c.file('atmos/bar.yml', YAML.dump(bar: "bum"))
            conf = SettingsHash.new
            result = config.send(:load_config_sources, "#{c}/config", conf, "#{c}/atmos/*.yml")
            expect(result).to_not be conf
            expect(result["foo"]).to eq("baz")
            expect(result["bar"]).to eq("bum")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/atmos/foo.yml", "#{c}/atmos/bar.yml"])
          end
        end

        it "loads from expandable pattern" do
          within_construct do |c|
            c.file('home/foo.yml', YAML.dump(foo: "baz"))
            conf = SettingsHash.new

            result = nil
            ClimateControl.modify("HOME" => "#{c}/home") do
              result = config.send(:load_config_sources, "#{c}/config", conf, "~/*.yml")
            end

            expect(result).to_not be conf
            expect(result["foo"]).to eq("baz")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/home/foo.yml"])
          end
        end

        it "loads from multiple patterns" do
          within_construct do |c|
            c.file('config/atmos/foo.yml', YAML.dump(bar: "baz"))
            c.file('atmos/bar.yml', YAML.dump(baz: "bum"))
            conf = SettingsHash.new
            result = config.send(:load_config_sources, "#{c}/config", conf, "atmos/*.yml", "#{c}/atmos/*.yml")
            expect(result).to_not be conf
            expect(result["bar"]).to eq("baz")
            expect(result["baz"]).to eq("bum")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/config/atmos/foo.yml", "#{c}/atmos/bar.yml"])
          end
        end

        it "skips bad files" do
          within_construct do |c|
            c.file('config/atmos/foo.yml', YAML.dump(foo: "baz"))
            c.file('config/atmos/bar.yml', "")
            c.file('config/atmos/baz.yml', "true")
            conf = SettingsHash.new
            result = config.send(:load_config_sources, "#{c}/config", conf, "atmos/*.yml")
            expect(result).to_not be conf
            expect(result["foo"]).to eq("baz")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/config/atmos/foo.yml"])
            expect(Logging.contents).to_not match(/Skipping.*foo.yml/)
            expect(Logging.contents).to match(/Skipping.*bar.yml/)
            expect(Logging.contents).to match(/Skipping.*baz.yml/)
          end
        end

        it "merges config additively" do
          within_construct do |c|
            c.file('config/atmos/foo.yml', YAML.dump(foo: [1], bar: {baz: "boo"}))
            c.file('config/atmos/bar.yml', YAML.dump(foo: [2], bar: {bum: "hum"}))
            conf = SettingsHash.new
            result = config.send(:load_config_sources, "#{c}/config", conf, "atmos/*.yml")
            expect(result).to_not be conf
            expect(result["foo"]).to eq([1, 2])
            expect(result["bar"]["baz"]).to eq("boo")
            expect(result["bar"]["bum"]).to eq("hum")
          end
        end

      end

      describe "load_remote_config_sources" do

        it "does nothing if no sources" do
          within_construct do |c|
            conf = SettingsHash.new
            result = config.send(:load_remote_config_sources, conf)
            expect(result).to be conf
          end
        end

        it "loads from single remote source" do
          within_construct do |c|
            yml_url = "http://www.example.com/foo.yml"
            stub_request(:get, yml_url).to_return(body: YAML.dump(foo: "bar"))

            conf = SettingsHash.new
            result = config.send(:load_remote_config_sources, conf, yml_url)
            expect(result).to_not be conf
            expect(result["foo"]).to eq("bar")
            expect(config.instance_variable_get(:@included_configs).keys).to eq([yml_url])
          end
        end

        it "skips bad files" do
          within_construct do |c|
            yml_url1 = "http://www.example.com/foo.yml"
            stub_request(:get, yml_url1).to_return(body: YAML.dump(foo: "bar"))
            yml_url2 = "http://www.example.com/bar.yml"
            stub_request(:get, yml_url2).to_return(body: "")
            yml_url3 = "http://www.example.com/baz.yml"
            stub_request(:get, yml_url3).to_return(body: "true")

            conf = SettingsHash.new
            result = config.send(:load_remote_config_sources, conf, yml_url1, yml_url2, yml_url3)
            expect(result).to_not be conf
            expect(result["foo"]).to eq("bar")
            expect(config.instance_variable_get(:@included_configs).keys).to eq([yml_url1])
            expect(Logging.contents).to_not match(/Skipping.*foo.yml/)
            expect(Logging.contents).to match(/Skipping.*bar.yml/)
            expect(Logging.contents).to match(/Skipping.*baz.yml/)
          end
        end

        it "merges config additively" do
          within_construct do |c|
            yml_url1 = "http://www.example.com/foo.yml"
            stub_request(:get, yml_url1).to_return(body: YAML.dump(foo: [1], bar: {baz: "boo"}))
            yml_url2 = "http://www.example.com/bar.yml"
            stub_request(:get, yml_url2).to_return(body: YAML.dump(foo: [2], bar: {bum: "hum"}))

            conf = SettingsHash.new
            result = config.send(:load_remote_config_sources, conf, yml_url1, yml_url2)
            expect(result).to_not be conf
            expect(result["foo"]).to eq([1, 2])
            expect(result["bar"]["baz"]).to eq("boo")
            expect(result["bar"]["bum"]).to eq("hum")
          end
        end

      end

      describe "load_submap" do

        it "does nothing if no submap" do
          within_construct do |c|
            conf = SettingsHash.new
            result = config.send(:load_submap, "", "environments", "dev", conf)
            expect(result).to be conf
          end
        end

        it "loads from submap" do
          within_construct do |c|
            c.file('config/atmos/environments/dev.yml', YAML.dump(foo: "bar"))
            conf = SettingsHash.new
            result = config.send(:load_submap, "#{c}/config", "environments", "dev", conf)
            expect(result).to_not be conf
            expect(result["environments"]["dev"]["foo"]).to eq("bar")
            expect(result["foo"]).to eq("bar")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/config/atmos/environments/dev.yml"])
          end
        end

        it "skips empty files" do
          within_construct do |c|
            c.file('config/atmos/environments/dev.yml', "")
            conf = SettingsHash.new
            result = config.send(:load_submap, "#{c}/config", "environments", "dev", conf)
            expect(result).to be conf
            expect(Logging.contents).to match(/Skipping.*dev.yml/)
          end
        end

        it "skips bad files" do
          within_construct do |c|
            c.file('config/atmos/environments/dev.yml', "true")
            conf = SettingsHash.new
            result = config.send(:load_submap, "#{c}/config", "environments", "dev", conf)
            expect(result).to be conf
            expect(Logging.contents).to match(/Skipping.*dev.yml/)
          end
        end

        it "merges config additively" do
          within_construct do |c|
            c.file('config/atmos/environments/dev.yml', YAML.dump(foo: [1], bar: {baz: "boo"}))
            conf = SettingsHash.new(environments: {dev: {foo: [2], bar: {bum: "hum"}}})
            result = config.send(:load_submap, "#{c}/config", "environments", "dev", conf)
            expect(result).to_not be conf
            expect(result["environments"]["dev"]["foo"]).to eq([2, 1])
            expect(result["foo"]).to eq([2, 1])
            expect(result["environments"]["dev"]["bar"]["baz"]).to eq("boo")
            expect(result["bar"]["baz"]).to eq("boo")
            expect(result["environments"]["dev"]["bar"]["bum"]).to eq("hum")
            expect(result["bar"]["bum"]).to eq("hum")
            expect(config.instance_variable_get(:@included_configs).keys).to eq(["#{c}/config/atmos/environments/dev.yml"])
          end
        end

      end

      describe "load_file" do

        it "logs if config file not present" do
          within_construct do |c|
            config.send(:load_file, "#{c}/foo.yml")
            expect(Logging.contents).to include("Could not find an atmos config file at: #{c}/foo.yml")
            expect(config.instance_variable_get(:@included_configs).keys).to_not include("#{c}/foo.yml")
          end
        end

        it "logs if bad file" do
          within_construct do |c|
            c.file('foo.yml', "true")
            config.send(:load_file, "#{c}/foo.yml")
            expect(Logging.contents).to include("Skipping invalid atmos config (not hash-like): #{c}/foo.yml")
            expect(config.instance_variable_get(:@included_configs).keys).to_not include("#{c}/foo.yml")
          end
        end

        it "loads config" do
          within_construct do |c|
            c.file('foo.yml', YAML.dump(foo: "bar"))
            result = config.send(:load_file, "#{c}/foo.yml")
            expect(result[:foo]).to eq("bar")
            expect(config.instance_variable_get(:@included_configs).keys).to include("#{c}/foo.yml")
          end
        end

        it "merges loaded config" do
          within_construct do |c|
            c.file('foo.yml', YAML.dump(foo: "bar"))
            result = config.send(:load_file, "#{c}/foo.yml", SettingsHash.new({bar: "baz"}))
            expect(result[:foo]).to eq("bar")
            expect(result[:bar]).to eq("baz")
            expect(config.instance_variable_get(:@included_configs).keys).to include("#{c}/foo.yml")
          end
        end

        it "applies block to loaded config" do
          within_construct do |c|
            c.file('foo.yml', YAML.dump(foo: "bar"))
            result = config.send(:load_file, "#{c}/foo.yml") do |d|
              d[:hum] = "dum"
              d
            end
            expect(result[:foo]).to eq("bar")
            expect(result[:hum]).to eq("dum")
            expect(config.instance_variable_get(:@included_configs).keys).to include("#{c}/foo.yml")
          end
        end

      end

      describe "save_user_config_file" do

        it "saves to user file" do
          within_construct do |c|
            allow(config).to receive(:user_config_file).and_return("#{c}/home.yml")
            config.send(:save_user_config_file, {"foo" => "bar"})
            expect(YAML.load_file("#{c}/home.yml")).to eq({"foo" => "bar"})
            mode = File.stat("#{c}/home.yml").mode
            expect(sprintf("%o", mode)).to match(/0600$/)
          end
        end

        it "merges when saving to user file" do
          within_construct do |c|
            c.file("home.yml", YAML.dump(baz: "bum"))
            allow(config).to receive(:user_config_file).and_return("#{c}/home.yml")
            config.send(:save_user_config_file, {"foo" => "bar"}, merge_to_existing: true)
            expect(YAML.load_file("#{c}/home.yml")).to eq({"foo" => "bar", "baz" => "bum"})
          end
        end

        it "can skip merges when saving to user file" do
          within_construct do |c|
            c.file("home.yml", YAML.dump(baz: "bum"))
            allow(config).to receive(:user_config_file).and_return("#{c}/home.yml")
            config.send(:save_user_config_file, {"foo" => "bar"}, merge_to_existing: false)
            expect(YAML.load_file("#{c}/home.yml")).to eq({"foo" => "bar"})
          end
        end

      end

      describe "load" do

        it "warns if main config file not present" do
          within_construct do |c|
            config.send(:load)
            expect(Logging.contents).to match(/Could not find an atmos config file/)
            expect(config.instance_variable_get(:@included_configs).keys).to_not include(config.config_file)
          end
        end

        it "warns if bad file" do
          within_construct do |c|
            c.file('config/atmos.yml', "true")
            expect(config.instance_variable_defined?(:@full_config)).to be false
            expect(config.instance_variable_defined?(:@config)).to be false
            config.send(:load)
            expect(Logging.contents).to include("Skipping invalid atmos config (not hash-like): #{config.config_file}")
            expect(config.instance_variable_get(:@included_configs).keys).to_not include(config.config_file)
          end
        end

        it "loads config" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar"))
            expect(config.instance_variable_defined?(:@full_config)).to be false
            expect(config.instance_variable_defined?(:@config)).to be false
            config.send(:load)
            expect(config.instance_variable_defined?(:@full_config)).to be true
            expect(config.instance_variable_defined?(:@config)).to be true
            expect(config.instance_variable_get(:@included_configs)).to be_empty # hash emptied out to allow GC
          end
        end

        it "loads additional configs" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", hum: "not", atmos: {config_sources: "atmos/*.y{,a}ml"}))
            c.file('config/atmos/foo.yml', YAML.dump(bar: "baz"))
            c.file('config/atmos/bar.yaml', YAML.dump(baz: "bum", hum: "yes"))
            config.send(:load)
            expect(config["foo"]).to eq("bar")
            expect(config["bar"]).to eq("baz")
            expect(config["baz"]).to eq("bum")
            expect(config["hum"]).to eq("yes")
          end
        end

        it "loads user config" do
          allow(config).to receive(:load_file).and_call_original
          expect(config).to receive(:load_file).with(File.expand_path("~/.atmos.yml"), any_args)
          config.send(:load)
        end

        it "loads custom user config" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", hum: "not", atmos: {user_config: "#{c}/home"}))
            c.file('home', YAML.dump(bar: "baz"))
            config.send(:load)
            expect(config["foo"]).to eq("bar")
            expect(config["bar"]).to eq("baz")
          end
        end

        it "excludes special keys" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar",
                                                 providers: {}, environments: {}))
            config.send(:load)
            expect(config["providers"]).to be_nil
            expect(config["environments"]).to be_nil
          end
        end

        it "defaults provider to aws" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar"))
            config.send(:load)
            expect(config["provider"]).to eq("aws")
          end
        end

        it "merges in provider config" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", hum: "not",
                                                 provider: "aws", providers: {aws: {hum: "yes"}}))
            config.send(:load)
            expect(config["foo"]).to eq("bar")
            expect(config["hum"]).to eq("yes")
          end
        end

        it "merges in env config" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", hum: "not",
                                                 environments: {dev: {hum: "yes"}}))
            config = described_class.new("dev")
            expect(config["foo"]).to eq("bar")
            expect(config["hum"]).to eq("yes")
          end
        end

        it "merges additively env config" do
          within_construct do |c|

            c.file('config/atmos.yml', YAML.dump(foo: [1], atmos: {config_sources: "atmos/*.yml"}))
            c.file('config/atmos/foo.yml', YAML.dump(foo: [2]))
            c.file('config/atmos/provider.yml', YAML.dump(provider: "aws", providers: {aws: {foo: [3]}}))
            c.file('config/atmos/env.yml', YAML.dump(environments: {dev: {foo: [4]}}))

            config = described_class.new("dev")
            expect(config["foo"]).to eq([1, 2, 3, 4])
          end
        end

        it "supplies atmos_env" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar"))
            config = described_class.new("dev")
            expect(config["atmos_env"]).to eq("dev")
          end
        end

        it "supplies atmos_version" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar"))
            expect(config["atmos_version"]).to eq(VERSION)
          end
        end

      end

      describe "additive merge" do

        let(:additive_merge) { config.class.const_get(:ADDITIVE_MERGE) }

        it "handles empty merge" do
          lhs = {}
          rhs = {}
          expect(config.send(:config_merge, lhs, rhs)).to eq({})
        end

        it "performs deep merge additively" do
          lhs = {x: 1, y: [1, 2], z: "foo", h: {a: 9, c: 7}}
          rhs = {x: 2, y: [3, 4], z: "bar", h: {b: 8, c: 6}}
          expect(config.send(:config_merge, lhs, rhs)).to eq({x: 2, y: [1, 2, 3, 4], z: "bar", h: {a: 9, b: 8, c: 6}})
        end

        it "performs disjoint deep merge additively (handles nils)" do
          lhs = {x: {y: 9}, b: [{c: 7}], l: ['foo'], n: nil}
          rhs = {a: {b: 8}, y: [6], l: nil, o: nil}
          expect(config.send(:config_merge, lhs, rhs)).to eq({x: {y: 9}, y: [6], a: {b: 8}, b: [{c: 7}], l: ['foo'], n: nil, o: nil})
          expect(config.send(:config_merge, rhs, lhs)).to eq({x: {y: 9}, y: [6], a: {b: 8}, b: [{c: 7}], l: ['foo'], n: nil, o: nil})
          expect(Logging.contents).to_not match(/Different types in deep merge/)
        end

        it "allows array override" do
          lhs = {"y" => [1, 2]}
          rhs = {"^y" => [3, 4]}
          expect(config.send(:config_merge, lhs, rhs)).to eq({"y" => [3, 4]})
        end

        it "handles override in same hash" do
          lhs = {"y" => [1, 2], "^y" => [3, 4]}
          rhs = {}
          expect(config.send(:config_merge, lhs, rhs)).to eq({"y" => [3, 4]})
        end

        it "ignores override on lhs" do
          lhs = {"^y" => [1, 2]}
          rhs = {"y" => [3, 4]}
          expect(config.send(:config_merge, lhs, rhs)).to eq({"y" => [1, 2, 3, 4]})
        end

        it "allows hash override" do
          lhs = {"y" => {1 => 2}}
          rhs = {"^y" => {3 => 4}}
          expect(config.send(:config_merge, lhs, rhs)).to eq({"y" => {3 => 4}})
        end

        it "allows hash override with symbols" do
          # only preserves if it is a symbol, doesn't make things indifferent -
          # relies on Hashie on passed in args for that
          lhs = {y: {1 => 2}}
          rhs = {"^y": {3 => 4}}
          expect(config.send(:config_merge, lhs, rhs)).to eq({y: {3 => 4}})
        end

        it "warns on type mismatch" do
          lhs = {h: {a: {b: "foo"}}}
          rhs = {h: {a: {b: ["bar"]}}}
          expect(config.send(:config_merge, lhs, rhs, ["filename"])).to eq({h: {a: {b: ["bar"]}}})
          expect(Logging.contents).to match(/Type mismatch.*filename/)
          expect(Logging.contents).to match(/Deep merge LHS \(String\): "foo"/)
          expect(Logging.contents).to match(/Deep merge RHS \(Array\): \["bar"\]/)
          expect(Logging.contents).to match(/Deep merge path: h -> a -> b/)
        end

      end

      describe "add_user_load_path" do

        it "does nothing if no paths" do
          lp = $LOAD_PATH.dup
          config.add_user_load_path
          expect($LOAD_PATH).to eq(lp)
        end

        it "loads from single relative path" do
          lp = $LOAD_PATH.dup
          config_hash.notation_put("atmos.load_path", "foo")
          config.add_user_load_path
          expect($LOAD_PATH.length).to eq(lp.length + 1)
          expect($LOAD_PATH.first).to eq("#{config.root_dir}/foo")
        end

        it "loads from single absolute path" do
          lp = $LOAD_PATH.dup
          config_hash.notation_put("atmos.load_path", "/foo")
          config.add_user_load_path
          expect($LOAD_PATH.length).to eq(lp.length + 1)
          expect($LOAD_PATH.first).to eq("/foo")
        end

        it "loads from expandable path" do
          lp = $LOAD_PATH.dup
          config_hash.notation_put("atmos.load_path", "~/lib")
          ClimateControl.modify("HOME" => "/tmp") do
            config.add_user_load_path
          end
          expect($LOAD_PATH.length).to eq(lp.length + 1)
          expect($LOAD_PATH.first).to eq("/tmp/lib")
        end

        it "loads from multiple paths" do
          lp = $LOAD_PATH.dup
          config_hash.notation_put("atmos.load_path", ["foo", "bar"])
          config.add_user_load_path
          expect($LOAD_PATH.length).to eq(lp.length + 2)
          expect($LOAD_PATH[0]).to eq("#{config.root_dir}/foo")
          expect($LOAD_PATH[1]).to eq("#{config.root_dir}/bar")
        end

        it "loads from args path" do
          lp = $LOAD_PATH.dup
          config_hash.notation_put("atmos.load_path", ["foo", "bar"])
          config.add_user_load_path("baz", "boo")
          expect($LOAD_PATH.length).to eq(lp.length + 4)
          expect($LOAD_PATH[0]).to eq("#{config.root_dir}/baz")
          expect($LOAD_PATH[1]).to eq("#{config.root_dir}/boo")
          expect($LOAD_PATH[2]).to eq("#{config.root_dir}/foo")
          expect($LOAD_PATH[3]).to eq("#{config.root_dir}/bar")
        end

      end

    end

  end
end
