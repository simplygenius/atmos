require 'atmos/config'

describe Atmos::Config do

  let(:config) { described_class.new("ops") }

  describe "initialize" do

    it "sets up accessors" do
      env = "ops"
      config = described_class.new(env)
      expect(config.atmos_env).to eq(env)
      expect(config.root_dir).to eq(Dir.pwd)
      expect(config.config_file).to eq("#{Dir.pwd}/config/atmos.yml")
      expect(config.configs_dir).to eq("#{Dir.pwd}/config/atmos")
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
        expect(config.provider).to be_instance_of(Atmos::Providers::Aws::Provider)
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

  describe "load" do

    it "warns if main config file not present" do
      within_construct do |c|
        config.send(:load)
        expect(Atmos::Logging.contents).to match(/Could not find an atmos config file/)
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
      end
    end

    it "loads additional configs" do
      within_construct do |c|
        c.file('config/atmos.yml', YAML.dump(foo: "bar", hum: "not"))
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
        expect(config["atmos_version"]).to eq(Atmos::VERSION)
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

  end

end
