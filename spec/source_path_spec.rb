require 'simplygenius/atmos/source_path'
require 'zip'

module SimplyGenius
  module Atmos

    describe SourcePath do

      include TestConstruct::Helpers

      let(:sp) { described_class.new("myname", "mylocation") }

     def with_templates
        within_construct do |c|
          c.file('notemplate/foo')
          c.file('template1/templates.yml', "config: true")
          c.file('template1/templates.rb', "#actions")
          c.file('subdir1/template2/templates.yml')
          yield c, described_class.new("myname", c.to_s)
        end
      end

      def git_repo_fixture
        tmpdir = Dir.mktmpdir("git-repo-fixture-")
        at_exit { FileUtils.remove_entry(tmpdir) }
        open("#{fixture_dir}/template_repo.git.zip", 'rb') do |io|
          Zip::File.open_buffer(io) do |zip_file|
            zip_file.each do |f|
              fpath = File.join(tmpdir, f.name)
              f.extract(fpath)
            end
          end
        end
        return "#{tmpdir}/template_repo.git"
      end

      describe "to_s" do

        it "provides a string" do
          expect(sp.to_s).to eq "myname (mylocation)"
        end

      end

      describe "to_h" do

        it "provides a hash" do
          expect(sp.to_h).to eq({"name" => "myname", "location" => "mylocation"})
        end

      end

      describe "directory" do

        it "only expands once" do
          expect(sp).to receive(:expand_location).once.and_return("/")
          sp.directory
          sp.directory
        end

        it "only expands bad location once" do
          expect(sp).to receive(:expand_location).once.and_return(nil)
          sp.directory
          sp.directory
        end

      end

      describe "templates" do

        it "returns the templates hash" do
          with_templates do |c, sp|
            expect(sp.send(:templates).size).to eq(2)
            expect(sp.send(:templates)['template1']).to match instance_of(Template)
            expect(sp.send(:templates)['template1'].name).to eq('template1')
            expect(sp.send(:templates)['template1'].directory).to eq("#{c}/template1")
            expect(sp.send(:templates)['template1'].source).to be sp
            expect(sp.send(:templates)['subdir1/template2']).to match instance_of(Template)
          end
        end

      end

      describe "template" do

        it "returns the named template" do
          with_templates do |c, sp|
            expect(sp.template("template1")).to match instance_of(Template)
            expect(sp.template("template1").name).to eq('template1')
            expect(sp.template("template1").directory).to eq("#{c}/template1")
            expect(sp.template("template1").source).to be sp
            expect(sp.template("subdir1/template2")).to match instance_of(Template)
          end
        end

      end

      describe "template_names" do

        it "returns all template names sorted" do
          with_templates do |c, sp|
            expect(sp.template_names).to eq(["subdir1/template2", "template1"])
          end
        end

        it "ignores directories with special names" do
          with_templates do |c, sp|
            c.file('foo.bar/templates.yml')
            c.file('svn/templates.yml')
            c.file('CVS/templates.yml')
            c.file('git/templates.yml')
            c.file('.not/templates.yml')
            expect(sp.template_names).to eq(["foo.bar", "subdir1/template2", "template1"])
          end
        end

      end

      describe "expand_location", :vcr do

        it "passes through local path" do
          expanded = described_class.new("test", __dir__)
          expect(expanded.directory).to eq(__dir__)
        end

        it "normalizes local path with trailing slash" do
          path = "#{__dir__}/"
          expanded = described_class.new("test", path)
          expect(expanded.directory).to eq(__dir__)
        end

        it "expands local path" do
          expanded = described_class.new("test", "~")
          expect(expanded.directory).to match(/^\//)
        end

        it "skips a bad git archive" do
          within_construct do |c|
            c.file("bad.git")
            expanded = described_class.new("test", "bad.git")
            expect(expanded.directory).to be_nil
            expect(Logging.contents).to match(/Could not read from git/)
          end
        end

        it "expands a git archive locally" do
          repo_dir = git_repo_fixture
          expanded = described_class.new("test", repo_dir)
          expect(expanded.directory).to match(/^\/.*/)
          expect(Dir.exist?(expanded.directory)).to be true
          expect(expanded.template('template1').directory).to start_with(expanded.directory)
        end

        it "uses subdir from a git archive" do
          repo_dir = git_repo_fixture
          expanded = described_class.new("test", "#{repo_dir}#subdir")
          expect(expanded.directory).to match(/^\/.*/)
          expect(expanded.directory).to match(/subdir$/)
          expect(Dir.exist?(expanded.directory)).to be true
        end

        it "skips a bad zip archive" do
          within_construct do |c|
            c.file("bad.zip", "not a zip file")
            expanded = described_class.new("test", "bad.zip")
            expect(expanded.directory).to be_nil
            expect(Logging.contents).to match(/Could not read from zip/)
          end
        end

        it "expands a zip archive locally" do
          expanded = described_class.new("test", "#{fixture_dir}/template_repo.zip")
          expect(expanded.directory).to match(/^\/.*/)
          expect(Dir.exist?(expanded.directory)).to be true
        end

        it "expands a remote zip archive locally" do
          expanded = described_class.new("test", "https://github.com/simplygenius/atmos-recipes/archive/v0.7.0.zip")
          expect(expanded.directory).to match(/^\/.*/)
          expect(Dir.exist?(expanded.directory)).to be true
          expect(Dir.entries(expanded.directory)).to include("atmos-recipes-0.7.0")
        end

        it "uses subdir from a zip archive" do
          expanded = described_class.new("test", "#{fixture_dir}/template_repo.zip#template_repo")
          expect(expanded.directory).to match(/^\/.*/)
          expect(expanded.directory).to match(/template_repo$/)
          expect(Dir.exist?(expanded.directory)).to be true
          expect(expanded.template('template1').directory).to start_with(expanded.directory)
        end

      end

      describe "registry" do

        before(:each) { SourcePath.clear_registry }

        it "provides a registry" do
          expect(SourcePath.registry).to eq({})
        end

        it "adds to registry" do
          SourcePath.register("registeredsp", "registeredlocation")
          expect(SourcePath.registry.size).to eq(1)
          expect(SourcePath.registry.keys.first).to eq("registeredsp")
          expect(SourcePath.registry.values.first).to match instance_of(SourcePath)
          expect(SourcePath.registry.values.first.name).to eq("registeredsp")
          expect(SourcePath.registry.values.first.location).to eq("registeredlocation")
        end

        it "requires unique names in registry" do
          SourcePath.register("registeredsp", "registeredlocation")
          expect { SourcePath.register("registeredsp", "otherlocation") }.to raise_error(ArgumentError, /uniquely named/)
        end

        it "finds template in registry" do
          within_construct do |c|
            c.file('sp1/template1/templates.yml')
            c.file('sp1/templatedupe/templates.yml')
            c.file('sp2/template2/templates.yml')
            c.file('sp2/templatedupe/templates.yml')
            sp1 = SourcePath.register("sp1", "#{c}/sp1")
            sp2 = SourcePath.register("sp2", "#{c}/sp2")
            tmpl = SourcePath.find_template('template1')
            expect(tmpl.name).to eq('template1')
            expect(tmpl.source).to eq(sp1)
            expect(tmpl.directory).to eq("#{c}/sp1/template1")
            tmpl = SourcePath.find_template('template2')
            expect(tmpl.name).to eq('template2')
            expect(tmpl.source).to eq(sp2)
            expect(tmpl.directory).to eq("#{c}/sp2/template2")

            expect {SourcePath.find_template('notemplate') }.to raise_error(ArgumentError, /Could not find/)
            expect {SourcePath.find_template('templatedupe') }.to raise_error(ArgumentError, /must be unique/)
          end
        end

      end

    end

  end
end
