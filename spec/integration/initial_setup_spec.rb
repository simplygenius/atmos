require 'open3'

describe "Initial Setup" do

  let(:exe) { File.expand_path('../../../exe/atmos', __FILE__) }

  let(:recipes_sourcepath) {
    if ENV['CI'].present?
      []
    else
      ["--sourcepath", File.expand_path('../../../../atmos-recipes', __FILE__)]
    end
  }

  def atmos(*args, output_on_fail: true, allow_fail: false, stdin_data: nil)
    args = args.compact
    output, status = Open3.capture2e("bundle", "exec", exe, *args, stdin_data: stdin_data)
    puts output if output_on_fail && status.exitstatus != 0
    if ! allow_fail
      expect(status.exitstatus).to be(0), "atmos #{args.join(' ')} failed"
    end
    return output
  end

  describe "new repo" do

    it "initializes a new repo" do
      within_construct do |c|
        output = atmos "new"
        expect(File.exist?('config/atmos.yml')).to be true
        output = atmos "generate", *recipes_sourcepath, "aws/scaffold",
                       stdin_data: "acme\n123456789012\n"
        expect(File.exist?('config/atmos/aws.yml')).to be true
      end
    end

  end

end
