require "atmos/commands/generate"

describe Atmos::Commands::Generate do

  let(:cli) { described_class.new("") }

  describe "--help" do

    it "produces help text under standard width" do
      lines = cli.help.split("\n")
      lines.each {|l| expect(l.size).to be <= 80 }
    end

  end

  describe "execute" do

    it "generates a template" do
      within_construct do |d|
        cli.run(["--quiet", "init"])
        expect(File.exist?('config/atmos.yml'))
      end
    end

  end

end
