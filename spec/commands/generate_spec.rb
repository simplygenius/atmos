require "atmos/commands/generate"

describe Atmos::Commands::Generate do

  let(:cli) { described_class.new("") }

  describe "--help" do

    it "produces help text under standard width" do
      expect(cli.help).to be_line_width_for_cli
    end

  end

  describe "--sourcepath" do

    it "adds given sourcepaths to default" do
      within_construct do |c|
        c.directory('foo')
        within_construct do |d|
          d.directory('bar')

          cli.run(["--sourcepath", c.to_s, "--sourcepath", d.to_s, "--list"])
          expect(Atmos::Logging.contents).to include("new, foo, bar")
        end
      end
    end

    it "uses sourcepaths from config" do
      begin
        within_construct do |c|
          c.directory('foo')
          within_construct do |d|
            d.file("config/atmos.yml", YAML.dump(template_sources: [
                {
                  name: "local",
                  location: c.to_s
                }
            ]))
            Atmos.config = Atmos::Config.new("ops")

            cli.run(["--list"])
            expect(Atmos::Logging.contents).to match(/foo/)
          end
        end
      ensure
        Atmos.config = nil
      end
    end

  end

  describe "--list" do

    it "lists the templates" do
      within_construct do |c|
        c.directory('foo')
        c.directory('bar')

        cli.run(["--sourcepath", c.to_s, "--list"])
        expect(Atmos::Logging.contents).to include("bar, foo")
      end
    end

    it "lists the templates with a filter" do
      within_construct do |c|
        c.directory('foo')
        c.directory('bar')

        cli.run(["--sourcepath", c.to_s, "--list", "fo"])
        expect(Atmos::Logging.contents).to_not include("bar")
        expect(Atmos::Logging.contents).to include("foo")
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
        cli.run(["--quiet", "new"])
        expect(File.exist?('config/atmos.yml')).to be true
      end
    end

    it "generates an error for bad template" do
      within_construct do |d|
        expect { cli.run(["--quiet", "foo"]) }.to raise_error(ArgumentError)
      end
    end

    it "gives cli sourcepath precedence over config and builtin" do
      within_construct do |c|
        c.directory('new')
        c.file('new/foo.txt')

        within_construct do |d|
          d.directory('new')
          d.file('new/bar.txt')

          within_construct do |e|
            e.file("config/atmos.yml", YAML.dump(template_sources: [
                {
                  name: "local",
                  location: d.to_s
                }
            ]))
            Atmos.config = Atmos::Config.new("ops")
            cli.run(["--quiet", "--sourcepath", c.to_s, "new"])
            expect(File.exist?('foo.txt')).to be true
            expect(File.exist?('bar.txt')).to be false
            expect(File.exist?('.gitignore')).to be false
          end
        end
      end
    end

    it "gives config sourcepath precedence over builtin" do
      within_construct do |c|
        c.directory('new')
        c.file('new/foo.txt')

        within_construct do |d|
          d.file("config/atmos.yml", YAML.dump(template_sources: [
              {
                name: "local",
                location: c.to_s
              }
          ]))
          Atmos.config = Atmos::Config.new("ops")

          cli.run(["--quiet", "new"])
          expect(File.exist?('foo.txt')).to be true
          expect(File.exist?('.gitignore')).to be false
        end
      end

    end

  end

end
