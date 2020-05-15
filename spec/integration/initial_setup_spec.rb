require 'open3'
require 'simplygenius/atmos/settings_hash'

describe "Initial Setup" do

  let(:recipes_sourcepath) {
    if ENV['CI'].present?
      ["--no-sourcepaths", "--sourcepath", 'https://github.com/simplygenius/atmos-recipes.git']
    else
      ["--no-sourcepaths", "--sourcepath", File.expand_path('../../../../atmos-recipes', __FILE__)]
    end
  }

  describe "executable" do

    it "runs the cli" do
      within_construct do |c|
        c.file('config/atmos.yml', "foo: bar")

        output = atmos "version"
        expect(output).to include(SimplyGenius::Atmos::VERSION)
        expect(File.exist?('atmos.log')).to be true
        expect(File.read('atmos.log')).to include(SimplyGenius::Atmos::VERSION)
      end
    end

    it "it catches and formats errors" do
      within_construct do |c|
        c.file('config/atmos.yml', 'foo: "#{fail}"')

        output = atmos "config", allow_fail: true, output_on_fail: false
        expect(output).to match(/Failing config statement/)
        expect(output).to_not match(/\.rb:\d+:in /) # backtrace
      end
    end

    it "it shows full trace in debug" do
      within_construct do |c|
        c.file('config/atmos.yml', 'foo: "#{fail}"')

        output = atmos "--debug", "config", allow_fail: true, output_on_fail: false
        expect(output).to match(/Failing config statement/)
        expect(output).to match(/\.rb:\d+:in /) # backtrace
      end
    end

    it "can display cli help" do
      within_construct do |c|
        c.file('config/atmos.yml', "foo: bar")

        output = atmos "--help"
        expect(output).to match(/Usage:\n\s*atmos \[OPTIONS\] SUBCOMMAND \[ARG\] \.\.\./)
      end
    end

  end

  describe "new repo" do

    it "initializes a new repo" do
      within_construct do |c|
        output = atmos "new"
        expect(File.exist?('config/atmos.yml')).to be true
        output = atmos "generate", "--force", *recipes_sourcepath, "aws/scaffold",
                       stdin_data: "acme\n123456789012\n"
        expect(File.exist?('config/atmos/atmos-aws.yml')).to be true
        conf = SimplyGenius::Atmos::SettingsHash.new(YAML.load_file('config/atmos.yml'))
        expect(conf['org']).to eq("acme")
        expect(conf.notation_get('environments.ops.account_id')).to eq("123456789012")
      end
    end

  end

end
