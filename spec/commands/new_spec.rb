require "atmos/commands/new"

describe Atmos::Commands::New do

  let(:cli) { described_class.new("") }

  describe "--help" do

    it "produces help text under standard width" do
      expect(cli.help).to be_line_width_for_cli
    end

  end

  describe "execute" do

    it "generates the new template" do
      within_construct do |d|
        cli.run(["--quiet"])
        expect(File.exist?('config/atmos.yml'))
      end
    end

  end

end
