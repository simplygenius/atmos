require 'atmos/generator'

describe Atmos::Generator do

  include TestConstruct::Helpers

  let(:gen) { described_class.new([], quiet: true) }

  before(:each) do
    @orig_source_root = described_class.source_root
  end

  after(:each) do
    described_class.source_root(@orig_source_root)
  end

  describe "source_root" do

    it "defaults to templates dir in this repo" do
      expect(described_class.source_root).to eq(File.expand_path('../../templates', __FILE__))
      expect(described_class.source_root).to end_with('/atmos/templates')
    end

  end

  describe "valid_templates" do

    it "has contents of templates" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.directory('foo')
        c.directory('bar')
        c.directory('svn')
        c.directory('CVS')
        c.directory('.not')
        expect(described_class.valid_templates).to eq(['bar', 'foo'])
      end
    end

  end

  describe "find_dependencies" do

    it "handles simple dep" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => 'bar'))
        c.directory('bar')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar'])
      end
    end

    it "handles multiple deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar',  'baz']))
        c.directory('bar')
        c.directory('baz')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar', 'baz'])
      end
    end

    it "follows nested deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar']))
        c.file('bar/templates.yml', YAML.dump('dependent_templates' => ['baz']))
        c.directory('baz')
        expect(gen.send(:find_dependencies, 'foo')).to eq(['bar', 'baz'])
      end
    end

    it "provides a uniq set of deps" do
      within_construct do |c|
        described_class.source_root(c.to_s)
        c.file('foo/templates.yml', YAML.dump('dependent_templates' => ['bar', 'baz']))
        c.file('bar/templates.yml', YAML.dump('dependent_templates' => ['baz']))
        c.directory('baz')
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
        c.file('foo/foo.txt', "hello")
        within_construct do |d|
          gen.send(:apply_template, 'foo')
          expect(File.exist?('foo.txt')).to be true
          expect(open("#{d}/foo.txt").read).to eq(open("#{c}/foo/foo.txt").read)
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

    it "processes procedural template" do
      within_construct do |c|
        described_class.source_root(c.to_s)
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
        c.file('foo/foo.txt')
        c.file('bar/bar.txt')
        within_construct do |d|
          gen.generate(['foo', 'bar'])
          expect(File.exist?('foo.txt'))
          expect(File.exist?('bar.txt'))
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

end
