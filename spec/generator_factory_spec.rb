require 'atmos/generator_factory'

describe Atmos::GeneratorFactory do

  include TestConstruct::Helpers

  let(:gen) { described_class.new([], quiet: true) }


  describe "expand_sourcepaths", :vcr do

    it "does nothing for nothing" do
      expect(described_class.expand_sourcepaths([])).to eq([])
    end

    it "passes through local path" do
      expect(described_class.expand_sourcepaths([__FILE__])).to eq([__FILE__])
    end

    it "expands a git archive locally" do
      expanded = described_class.expand_sourcepaths(["#{fixture_dir}/template_repo.git"])
      expect(expanded.size).to eq(1)
      expect(expanded.first).to match(/^\/.*/)
      expect(Dir.exist?(expanded.first))
    end

    it "uses subdir from a git archive" do
      expanded = described_class.expand_sourcepaths(["#{fixture_dir}/template_repo.git#template_repo/subdir"])
      expect(expanded.size).to eq(1)
      expect(expanded.first).to match(/^\/.*/)
      expect(expanded.first).to match(/template_repo\/subdir$/)
      expect(Dir.exist?(expanded.first))
    end

    it "expands a zip archive locally" do
      expanded = described_class.expand_sourcepaths(["#{fixture_dir}/template_repo.zip"])
      expect(expanded.size).to eq(1)
      expect(expanded.first).to match(/^\/.*/)
      expect(Dir.exist?(expanded.first))
    end

    it "uses subdir from a zip archive" do
      expanded = described_class.expand_sourcepaths(["#{fixture_dir}/template_repo.zip#template_repo/subdir"])
      expect(expanded.size).to eq(1)
      expect(expanded.first).to match(/^\/.*/)
      expect(expanded.first).to match(/template_repo\/subdir$/)
      expect(Dir.exist?(expanded.first))
    end

  end

  describe "create" do

    it "creates a generator class instance with source paths set" do
      gen = described_class.create(['/foo', '/bar'])
      expect(gen).to be_a_kind_of(Atmos::Generator)
      expect(gen.source_paths).to eq(['/foo', '/bar'])
    end

  end

end
