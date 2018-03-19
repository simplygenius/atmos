require 'atmos/generator'

describe Atmos::Generator do

  include TestConstruct::Helpers

  let(:gen) { described_class.new([], quiet: true, force: true) }

  before(:each) do
    @orig_source_root = described_class.source_root
  end

  after(:each) do
    described_class.source_root(@orig_source_root)
  end

  describe "valid_templates" do

    it "has contents of templates" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('bar/baz/templates.yml')
        c.directory('hum')
        expect(described_class.valid_templates).to eq(['bar/baz', 'foo'])
      end
    end

    it "only shows directories as templates" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file("foo.txt")
        expect(described_class.valid_templates).to eq(['foo'])
      end
    end

    it "ignores directories with special names" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo.bar/templates.yml')
        c.file('svn/templates.yml')
        c.file('CVS/templates.yml')
        c.file('.not/templates.yml')
        expect(described_class.valid_templates).to eq(['foo', 'foo.bar'])
      end
    end

  end

  describe "find_dependencies" do

    it "handles simple dep" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => 'bar'))
        c.file('bar/templates.yml')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar'])
      end
    end

    it "handles nested dep" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/bar/templates.yml', YAML.dump('dependent_templates' => 'bar/baz'))
        c.file('bar/baz/templates.yml', YAML.dump('dependent_templates' => 'bum/boo'))
        c.file('bum/boo/templates.yml')
        expect(gen.send(:find_dependencies, 'foo/bar')).to eq(['bar/baz', 'bum/boo'])
      end
    end

    it "handles multiple deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar',  'baz']))
        c.file('bar/templates.yml')
        c.file('baz/templates.yml')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar', 'baz'])
      end
    end

    it "follows nested deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar']))
        c.file('bar/templates.yml', YAML.dump('dependent_templates' => ['baz']))
        c.file('baz/templates.yml')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar', 'baz'])
      end
    end

    it "provides a uniq set of deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar', 'baz']))
        c.file('bar/templates.yml', YAML.dump('dependent_templates' => ['baz']))
        c.file('baz/templates.yml')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar', 'baz'])
      end
    end

    it "handles circular" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar']))
        c.file('bar/templates.yml', YAML.dump('dependent_templates' => ['baz']))
        c.file('baz/templates.yml', YAML.dump('dependent_templates' => ['foo']))
        expect{gen.send(:find_dependencies, 'foo')}.to raise_error(ArgumentError, /Circular/)
      end
    end

  end

  describe "apply_template" do

    it "handles simple template" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo/foo.txt', "hello")
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('foo.txt')).to be true
          expect(open("#{d}/foo.txt").read).to eq(open("#{c}/foo/foo.txt").read)
        end
      end
    end

    it "handles nested template" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/bar/templates.yml')
        c.file('foo/bar/foo.txt', "hello")
        within_construct do |d|
          gen.send(:apply_template, 'foo/bar')
          expect(File.exist?('foo.txt')).to be true
          expect(open("#{d}/foo.txt").read).to eq(open("#{c}/foo/bar/foo.txt").read)
        end
      end
    end

    it "ignores template metadata" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo/templates.rb')
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('templates.yml')).to be false
          expect(File.exist?('templates.rb')).to be false
        end
      end
    end

    it "preserves directory structure" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo/sub/bar.txt', "there")
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('sub/bar.txt')).to be true
          expect(open("#{d}/sub/bar.txt").read).to eq(open("#{c}/foo/sub/bar.txt").read)
        end
      end
    end

    it "handles optional qualifier" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('optional' => {'sub/bar.txt' => 'false'}))
        c.file('foo/foo.txt', "hello")
        c.file('foo/sub/bar.txt', "there")
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('foo.txt')).to be true
          expect(File.exist?('sub/bar.txt')).to be false
        end
      end
    end

    it "optional qualifier sees helper methods" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('optional' => {
            'sub/foo.txt' => 'get_config("foo.yml", "not")',
            'sub/bar.txt' => 'get_config("foo.yml", "foo")'
        }))
        c.file('foo/foo.yml', YAML.dump("foo" => "bar"))
        c.file('foo/sub/foo.txt', "hello")
        c.file('foo/sub/bar.txt', "there")
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('sub/foo.txt')).to be false
          expect(File.exist?('sub/bar.txt')).to be true
        end
      end
    end

    it "processes procedural template" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo/templates.rb', 'append_to_file "foo.txt", "there"')
        c.file('foo/foo.txt', "hello")
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('foo.txt')).to be true
          expect(open("#{d}/foo.txt").read).to eq("hellothere")
        end
      end
    end

  end

  describe "generate" do

    it "generates single" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo/foo.txt')
        within_construct do |d|
          gen.generate('foo')
          expect(File.exist?('foo.txt'))
        end
      end
    end

    it "generates multiple" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml')
        c.file('foo/foo.txt')
        c.file('bar/templates.yml')
        c.file('bar/bar.txt')
        c.file('baz/boo/templates.yml')
        c.file('baz/boo/boo.txt')
        within_construct do |d|
          gen.generate(['foo', 'bar', 'baz/boo'])
          expect(File.exist?('foo.txt'))
          expect(File.exist?('bar.txt'))
          expect(File.exist?('boo.txt'))
        end
      end
    end

    it "generates with deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar']))
        c.file('foo/foo.txt')
        c.file('bar/templates.yml', YAML.dump('dependent_templates' => ['baz']))
        c.file('bar/bar.txt')
        c.file('baz/templates.yml')
        c.file('baz/baz.txt')
        within_construct do |d|
          gen.generate('foo')
          expect(File.exist?('foo.txt'))
          expect(File.exist?('bar.txt'))
          expect(File.exist?('baz.txt'))
        end
      end
    end

  end

  describe "custom template actions" do

    describe "raw_configs" do

      it "loads config file once" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo.yml', YAML.dump('foo' => 'bar'))

          expect(YAML).to receive(:load_file).once.with('foo.yml').and_call_original

          config = gen.send(:raw_config, 'foo.yml')
          expect(config).to be_a_kind_of(Atmos::SettingsHash)
          expect(config['foo']).to eq('bar')

          config = gen.send(:raw_config, 'foo.yml')
          expect(config).to be_a_kind_of(Atmos::SettingsHash)
          expect(config['foo']).to eq('bar')
        end
      end

    end

    describe "get_config" do

      it "gets config from yml" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}))

          expect(gen.send(:get_config, 'foo.yml', 'foo.bar')).to eq('baz')
        end
      end

    end

    describe "config_present?" do

      it "checks for presence" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}, 'list' => ['one']))

          expect(gen.send(:config_present?, 'foo.yml', 'foo.bar')).to be true
          expect(gen.send(:config_present?, 'foo.yml', 'list')).to be true
          expect(gen.send(:config_present?, 'foo.yml', 'blah')).to be false
        end
      end

      it "checks for simple value" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}))

          expect(gen.send(:config_present?, 'foo.yml', 'foo.bar', 'baz')).to be true
          expect(gen.send(:config_present?, 'foo.yml', 'foo.bar', 'not')).to be false
        end
      end

      it "checks for list contents" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo.yml', YAML.dump('foo' => {'bar' => ['hum', 'baz']}))

          expect(gen.send(:config_present?, 'foo.yml', 'foo.bar', 'baz')).to be true
          expect(gen.send(:config_present?, 'foo.yml', 'foo.bar', 'not')).to be false
          expect(gen.send(:config_present?, 'foo.yml', 'not', 'not')).to be false
        end
      end

    end

    describe "add_config" do

      it "adds to config file" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo/templates.yml')
          c.file('foo/templates.rb', 'add_config "config/atmos.yml", "foo.bar.baz", "bum"')
          within_construct do |d|
            data = {"foo" => {"bah" => 'blah'}, "hum" => 'hi'}
            d.file("config/atmos.yml", YAML.dump(data))
            gen.send(:apply_template, 'foo')
            new_data = YAML.load_file("config/atmos.yml")
            expect(new_data).to eq({"foo"=>{"bah"=>"blah", "bar"=>{"baz"=>"bum"}}, "hum"=>"hi"})
          end
        end
      end

    end

    describe "new_keys?" do

      it "checks if config has more keys" do
        within_construct do |c|
          described_class.source_root(c.to_s)
          c.file('foo/templates.yml')
          c.file('foo/templates.rb', 'new_keys? "#{template_dir}/foo.yml", "foo.yml"')
          data = {"foo" => 'bar', "hum" => 'hi'}
          c.file("foo.yml", YAML.dump(data))

          within_construct do |d|
            d.file("foo.yml", YAML.dump(data))
            expect(gen.send(:new_keys?, "#{d}/foo.yml", 'foo.yml')).to be false
          end

          within_construct do |d|
            d.file("foo.yml", YAML.dump({"foo" => 'bar'}))
            expect(gen.send(:new_keys?, "#{d}/foo.yml", 'foo.yml')).to be false
          end

          within_construct do |d|
            d.file("foo.yml", YAML.dump(data.merge("baz" => "bum")))
            expect(gen.send(:new_keys?, "#{d}/foo.yml", 'foo.yml')).to be true
          end
        end
      end

    end

  end
end
