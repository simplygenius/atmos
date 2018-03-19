require 'atmos/settings_hash'

describe Atmos::SettingsHash do

  describe "notation_get" do

    it "handles hash dot notation in keys" do
      config = described_class.new(foo: {bar: "baz"})
      expect(config.notation_get("foo.bar")).to eq("baz")
    end

    it "handles list dot notation in keys" do
      config = described_class.new(foo: ["bar", "baz"])
      expect(config.notation_get("foo.0")).to eq("bar")
      expect(config.notation_get("foo[1]")).to eq("baz")
    end

    it "handles deep dot notation in keys" do
      config = described_class.new(foo: {bar: [{baz: 'bum'}]})
      expect(config.notation_get("foo.bar.0.baz")).to eq("bum")
    end

    it "returns nil for keys that aren't present" do
      Atmos::Logging.setup_logging(true, false, nil)
      config = described_class.new
      expect(config.notation_get("foo.bar")).to be_nil
      expect(Atmos::Logging.contents).to match(/Settings missing value for key='foo.bar'/)
    end

  end

  describe "notation_put" do

    it "handles empty" do
      config = described_class.new
      config.notation_put("foo", "bar")
      expect(config["foo"]).to eq("bar")
    end

    it "puts list val" do
      config = described_class.new
      config.notation_put("foo", ["bar"])
      expect(config["foo"]).to eq(["bar"])
    end

    it "puts list val additively with list arg" do
      config = described_class.new
      config.notation_put("foo", ["bar"])
      config.notation_put("foo", ["baz"], additive: true)
      expect(config["foo"]).to eq(["bar", "baz"])
    end

    it "is additive by default" do
      config = described_class.new
      config.notation_put("foo", ["bar"])
      config.notation_put("foo", ["baz"])
      expect(config["foo"]).to eq(["bar", "baz"])
    end

    it "puts list val additively with scalar arg" do
      config = described_class.new
      config.notation_put("foo", ["bar"])
      config.notation_put("foo", "baz", additive: true)
      expect(config["foo"]).to eq(["bar", "baz"])
    end

    it "puts list val not-additively" do
      config = described_class.new
      config.notation_put("foo", ["bar"])
      config.notation_put("foo", ["baz"], additive: false)
      expect(config["foo"]).to eq(["baz"])
      config.notation_put("foo", "baz", additive: false)
      expect(config["foo"]).to eq("baz")
    end

    it "puts deeply" do
      config = described_class.new
      config.notation_put("foo.bar.baz", "bum")
      level = config["foo"]
      expect(level).to be_a_kind_of(Hash)
      expect(config.notation_get("foo")).to be_a_kind_of(Hash)
      level = level["bar"]
      expect(level).to be_a_kind_of(Hash)
      expect(config.notation_get("foo.bar")).to be_a_kind_of(Hash)
      level = level["baz"]
      expect(level).to eq("bum")
      expect(config.notation_get("foo.bar.baz")).to eq("bum")
    end

    it "puts list deeply" do
      config = described_class.new
      config.notation_put("foo.bar.baz", ["bum"])
      config.notation_put("foo.bar.baz", "boo", additive: true)
      expect(config.notation_get("foo.bar.baz")).to eq(["bum", "boo"])
    end

    it "uses list notation when putting list deeply" do
      config = described_class.new
      config.notation_put("foo.0.baz", "bum")
      expect(config.notation_get("foo.0.baz")).to eq("bum")
    end

    it "uses alternate list notation when putting list deeply" do
      config = described_class.new
      config.notation_put("foo[0].baz", "bum")
      expect(config.notation_get("foo[0].baz")).to eq("bum")
    end

  end

end
