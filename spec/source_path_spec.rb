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

      describe "template_dir" do

        it "returns the fully qualified template path" do
          with_templates do |c, sp|
            expect(sp.template_dir("notemplate")).to be_nil
            expect(sp.template_dir("template1")).to eq("#{c}/template1")
            expect(sp.template_dir("subdir1/template2")).to eq("#{c}/subdir1/template2")
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

      describe "template_actions_path" do

        it "returns the actions path" do
          with_templates do |c, sp|
            expect { sp.template_actions_path("notemplate") }.to raise_error(TypeError)
            expect(sp.template_actions_path("template1")).to eq("#{c}/template1/templates.rb")
            expect(sp.template_actions_path("subdir1/template2")).to eq("#{c}/subdir1/template2/templates.rb")
          end
        end

      end

      describe "template_actions" do

        it "returns the actions" do
          with_templates do |c, sp|
            expect { sp.template_actions("notemplate") }.to raise_error(TypeError)
            expect(sp.template_actions("template1")).to eq("#actions")
            expect(sp.template_actions("subdir1/template2")).to eq("")
          end
        end

        it "only reads action file once" do
          with_templates do |c, sp|
            expect(File).to receive(:read).once.and_return("#actions")
            sp.template_actions("template1")
            sp.template_actions("template1")
          end
        end

      end

      describe "template_config_path" do

        it "returns the config path" do
          with_templates do |c, sp|
            expect { sp.template_config_path("notemplate") }.to raise_error(TypeError)
            expect(sp.template_config_path("template1")).to eq("#{c}/template1/templates.yml")
            expect(sp.template_config_path("subdir1/template2")).to eq("#{c}/subdir1/template2/templates.yml")
          end
        end

      end

      describe "template_config" do

        it "returns the config" do
          with_templates do |c, sp|
            expect { sp.template_config("notemplate") }.to raise_error(TypeError)
            expect(sp.template_config("template1")).to eq({"config" => true})
            expect(sp.template_config("subdir1/template2")).to eq({})
          end
        end

        it "only reads config file once" do
          with_templates do |c, sp|
            expect(File).to receive(:read).once.and_return("#config")
            sp.template_config("template1")
            sp.template_config("template1")
          end
        end

      end

      describe "template_dependencies" do

        it "returns the dependencies" do
          with_templates do |c, sp|
            c.file("template3/templates.yml", {"dependent_templates" => ["one", "two"]}.to_yaml)
            c.file("template4/templates.yml", {"dependent_templates" => "one"}.to_yaml)
            expect { sp.template_dependencies("notemplate") }.to raise_error(TypeError)
            expect(sp.template_dependencies("template1")).to eq([])
            expect(sp.template_dependencies("template3")).to eq(["one", "two"])
            expect(sp.template_dependencies("template4")).to eq(["one"])
          end
        end

      end

      describe "template_optional" do

        it "returns the optional hash" do
          with_templates do |c, sp|
            c.file("template3/templates.yml", {"optional" => {"file1" => true}}.to_yaml)
            expect { sp.template_optional("notemplate") }.to raise_error(TypeError)
            expect(sp.template_optional("template1")).to eq({})
            expect(sp.template_optional("template3")).to eq({"file1" => true})
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
            c.file("bad.zip")
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
          expanded = described_class.new("test", "#{fixture_dir}/template_repo.zip#template_repo/subdir")
          expect(expanded.directory).to match(/^\/.*/)
          expect(expanded.directory).to match(/template_repo\/subdir$/)
          expect(Dir.exist?(expanded.directory)).to be true
        end

      end

    end

  end
end
