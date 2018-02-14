require "atmos/commands/generate"

describe Atmos::Commands::Generate do

  let(:cli) { described_class.new("") }

  describe "--help" do

    it "produces help text under standard width" do
      lines = cli.help.split("\n")
      lines.each {|l| expect(l.size).to be <= 80 }
    end

  end

  describe "--sourcepath" do

    it "adds given sourcepaths to default" do
      within_construct do |c|
        c.directory('foo')
        within_construct do |d|
          d.directory('bar')

          expect { cli.run(["--sourcepath", c.to_s, "--sourcepath", d.to_s, "--list"]) }.to output(/init, foo, bar/).to_stdout
        end
      end
    end

  end

  describe "--list" do

    it "lists the templates" do
      within_construct do |c|
        c.directory('foo')
        c.directory('bar')

        expect { cli.run(["--sourcepath", c.to_s, "--list"]) }.to output(/bar, foo/).to_stdout
      end
    end

    it "lists the templates with a filter" do
      within_construct do |c|
        c.directory('foo')
        c.directory('bar')

        expect { cli.run(["--sourcepath", c.to_s, "--list", "fo"]) }.to_not output(/bar/).to_stdout
        expect { cli.run(["--sourcepath", c.to_s, "--list", "fo"]) }.to output(/foo/).to_stdout
      end
    end

  end

  describe "execute" do

    it "requires a template param" do
      within_construct do |d|
        expect { cli.run([]) }.to raise_error(Clamp::UsageError, /template/)
      end
    end

    it "generates a template" do
      within_construct do |d|
        cli.run(["--quiet", "init"])
        expect(File.exist?('config/atmos.yml'))
      end
    end

  end

end
