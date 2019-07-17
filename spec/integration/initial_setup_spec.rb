require 'open3'
require 'simplygenius/atmos/settings_hash'

describe "Initial Setup" do

  let(:exe) { File.expand_path('../../../exe/atmos', __FILE__) }
  let(:gemfile) { File.expand_path('../../../Gemfile', __FILE__) }

  let(:recipes_sourcepath) {
    if ENV['CI'].present?
      ["--no-sourcepaths", "--sourcepath", 'https://github.com/simplygenius/atmos-recipes.git']
    else
      ["--no-sourcepaths", "--sourcepath", File.expand_path('../../../../atmos-recipes', __FILE__)]
    end
  }

  def atmos(*args, output_on_fail: true, allow_fail: false, stdin_data: nil)
    args = args.compact
    require 'bundler'
    ::Bundler.with_original_env do
      output, status = Open3.capture2e(ENV.to_h.merge("BUNDLE_GEMFILE" => gemfile), "bundle", "exec", exe, *args, stdin_data: stdin_data)
      puts output if output_on_fail && status.exitstatus != 0
      if ! allow_fail
        expect(status.exitstatus).to eq(0), "atmos #{args.join(' ')} failed: #{output}"
      end
      return output
    end
  end

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
