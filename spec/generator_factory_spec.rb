require 'simplygenius/atmos/generator_factory'
require 'zip'

module SimplyGenius
  module Atmos

    describe GeneratorFactory do

      include TestConstruct::Helpers

      let(:gen) { described_class.new([], quiet: true) }

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

      describe "expand_sourcepaths", :vcr do

        it "does nothing for nothing" do
          expect(described_class.expand_sourcepaths([])).to eq([])
        end

        it "passes through local path" do
          expect(described_class.expand_sourcepaths([__FILE__])).to eq([__FILE__])
        end

        it "skips a bad git archive" do
          within_construct do |c|
            c.file("bad.git")
            expanded = described_class.expand_sourcepaths(["bad.git"])
            expect(expanded.size).to eq(0)
            expect(Logging.contents).to match(/Could not read from git/)
          end
        end

        it "expands a git archive locally" do
          repo_dir = git_repo_fixture
          expanded = described_class.expand_sourcepaths([repo_dir])
          expect(expanded.size).to eq(1)
          expect(expanded.first).to match(/^\/.*/)
          expect(Dir.exist?(expanded.first)).to be true
        end

        it "uses subdir from a git archive" do
          repo_dir = git_repo_fixture
          expanded = described_class.expand_sourcepaths(["#{repo_dir}#subdir"])
          expect(expanded.size).to eq(1)
          expect(expanded.first).to match(/^\/.*/)
          expect(expanded.first).to match(/subdir$/)
          expect(Dir.exist?(expanded.first)).to be true
        end

        it "skips a bad zip archive" do
          within_construct do |c|
            c.file("bad.zip")
            expanded = described_class.expand_sourcepaths(["bad.zip"])
            expect(expanded.size).to eq(0)
            expect(Logging.contents).to match(/Could not read from zip/)
          end
        end

        it "expands a zip archive locally" do
          expanded = described_class.expand_sourcepaths(["#{fixture_dir}/template_repo.zip"])
          expect(expanded.size).to eq(1)
          expect(expanded.first).to match(/^\/.*/)
          expect(Dir.exist?(expanded.first)).to be true
        end

        it "expands a remote zip archive locally" do
          expanded = described_class.expand_sourcepaths(["https://github.com/simplygenius/atmos-recipes/archive/v0.7.0.zip"])
          expect(expanded.size).to eq(1)
          expect(expanded.first).to match(/^\/.*/)
          expect(Dir.exist?(expanded.first)).to be true
          expect(Dir.entries(expanded.first)).to include("atmos-recipes-0.7.0")
        end

        it "uses subdir from a zip archive" do
          expanded = described_class.expand_sourcepaths(["#{fixture_dir}/template_repo.zip#template_repo/subdir"])
          expect(expanded.size).to eq(1)
          expect(expanded.first).to match(/^\/.*/)
          expect(expanded.first).to match(/template_repo\/subdir$/)
          expect(Dir.exist?(expanded.first)).to be true
        end

      end

      describe "create" do

        it "creates a generator class instance with source paths set" do
          gen = described_class.create(['/foo', '/bar'])
          expect(gen).to be_a_kind_of(Generator)
          expect(gen.source_paths).to eq(['/foo', '/bar'])
        end

      end

    end

  end
end
