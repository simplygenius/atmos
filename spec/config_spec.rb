require 'simplygenius/atmos/config'
require 'climate_control'

module SimplyGenius
  module Atmos

    describe Config do

      let(:config) { described_class.new("ops") }

      describe "initialize" do

        it "sets up accessors" do
          env = "ops"
          config = described_class.new(env)
          expect(config.atmos_env).to eq(env)
          expect(config.root_dir).to eq(Dir.pwd)
          expect(config.config_file).to eq("#{Dir.pwd}/config/atmos.yml")
          expect(config.tmp_root).to eq("#{Dir.pwd}/tmp")
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
          within_construct do |c|
            expect(config.tf_working_dir('bootstrap')).
                to eq("#{config.tmp_root}/#{config.atmos_env}/tf/bootstrap")
            expect(Dir.exist?(config.tf_working_dir('bootstrap'))).to be true
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
            c.file('config/atmos.yml', "")
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
            expect(config.instance_variable_get(:@included_configs)).to eq(["#{c}/config/atmos/foo.yml", "#{c}/config/atmos/bar.yml"])
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
            expect(config.instance_variable_get(:@included_configs)).to eq(["#{c}/atmos/foo.yml", "#{c}/atmos/bar.yml"])
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
            expect(config.instance_variable_get(:@included_configs)).to eq(["#{c}/home/foo.yml"])
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
            expect(config.instance_variable_get(:@included_configs)).to eq(["#{c}/config/atmos/foo.yml", "#{c}/atmos/bar.yml"])
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

      describe "load" do

        it "warns if main config file not present" do
          within_construct do |c|
            config.send(:load)
            expect(Logging.contents).to match(/Could not find an atmos config file/)
            expect(config.instance_variable_get(:@included_configs)).to eq([])
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
            expect(config.instance_variable_get(:@included_configs)).to eq(["#{c}/config/atmos.yml"])
          end
        end

        it "loads additional configs" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", hum: "not", config_sources: "atmos/*.y{,a}ml"))
            c.file('config/atmos/foo.yml', YAML.dump(bar: "baz"))
            c.file('config/atmos/bar.yaml', YAML.dump(baz: "bum", hum: "yes"))
            config.send(:load)
            expect(config["foo"]).to eq("bar")
            expect(config["bar"]).to eq("baz")
            expect(config["baz"]).to eq("bum")
            expect(config["hum"]).to eq("yes")
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

            c.file('config/atmos.yml', YAML.dump(foo: [1], config_sources: "atmos/*.yml"))
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

      describe "expand" do

        it "handles simple interpolation" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", baz: '#{foo}'))
            expect(config["baz"]).to eq("bar")
          end
        end

        it "handles dot notation interpolation" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: {bar: ["boo"]}, baz: '#{foo.bar[0]}'))
            expect(config["baz"]).to eq("boo")
          end
        end

        it "prevents cycles in interpolation" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: '#{baz}', baz: '#{foo}'))
            expect { config["foo"] }.to raise_error(SystemStackError)
          end
        end

        it "handles complex eval" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: "bar", boo: {bum: "dum"}, baz: '#{foo.size * boo.bum.size}'))
            expect(config["baz"]).to eq("9")
          end
        end

        it "shows file/line for config error" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(baz: '#{foo.bar.size * 3}'))
            expect{config["baz"]}.
                to raise_error(RuntimeError,
                               /Failing config.*foo\.bar\.size.*atmos.yml:\d+ => NoMethodError.*/)
          end
        end

        it "handles truthy" do
          within_construct do |c|
            c.file('config/atmos.yml',
                   YAML.dump(foo: true, bar: false,
                             baz: '#{foo}', bum: '#{bar}',
                             foo2: 'true', bar2: 'false',
                             baz2: '#{foo2}', bum2: '#{bar2}'))
            expect(config["foo"]).to be true
            expect(config["bar"]).to be false
            expect(config["baz"]).to be true
            expect(config["bum"]).to be false
            expect(config["foo2"]).to be true
            expect(config["bar2"]).to be false
            expect(config["baz2"]).to be true
            expect(config["bum2"]).to be false
          end
        end

        it "handles additive merge hack" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(foo: ["^", "bar", ["^", "baz"]]))
            expect(config["foo"]).to eq(["bar", ["baz"]])
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
          lhs = {x: {y: 9}}
          rhs = {a: {b: 8}}
          expect(config.send(:config_merge, lhs, rhs)).to eq({x: {y: 9}, a: {b: 8}})
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

      end

    end

  end
end
