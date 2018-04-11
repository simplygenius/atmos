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

    it "does union when putting list val additively with list arg" do
      config = described_class.new
      config.notation_put("foo", ["bar"])
      config.notation_put("foo", ["baz"], additive: true)
      expect(config["foo"]).to eq(["bar", "baz"])
      config.notation_put("foo", ["baz", "boo"], additive: true)
      expect(config["foo"]).to eq(["bar", "baz", "boo"])
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

  describe "add_config" do

    it "adds to config file" do
        within_construct do |c|
          data = {"foo" => {"bah" => 'blah'}, "hum" => 'hi'}
          c.file("foo.yml", YAML.dump(data))
          new_yml = described_class.add_config("foo.yml", "foo.bar.baz", "bum")
          new_data = YAML.load(new_yml)
          expect(new_data).to eq({"foo"=>{"bah"=>"blah", "bar"=>{"baz"=>"bum"}}, "hum"=>"hi"})
        end
      end

    it "preserves comments when adding to config file" do
      within_construct do |c|
        data = <<~EOF
          # multi comment
          # line comment
          foo:
            # comment 1
            bah: blah
            # comment 2
            dum: bleh
          hum: hi
          empty:
          # comment 3
          dim:
          - sum
          # comment 4
          - bar
        EOF
        c.file("foo.yml", data)
        File.write("foo.yml", described_class.add_config("foo.yml", "foo.bar.baz", "bum"))
        File.write("foo.yml", described_class.add_config("foo.yml", "dim", "some"))
        File.write("foo.yml", described_class.add_config("foo.yml", "empty", "not"))

        new_data = File.read("foo.yml")
        expect(new_data.lines.grep(/comment/).length).to eq(6)
        new_data = YAML.load(new_data)
        expect(new_data['foo']['bar']['baz']).to eq('bum')
        expect(new_data['dim']).to eq(['sum', 'bar', 'some'])
        expect(new_data['empty']).to eq('not')
      end
    end

    it "check stock yml works" do
      within_construct do |c|
        yml = File.read(File.expand_path("../../templates/new/config/atmos.yml", __FILE__))
        c.file("foo.yml", yml)
        count = yml.lines.grep(/^#/).size

        File.write("foo.yml", described_class.add_config("foo.yml",
                                                         "recipes.default", ["atmos-scaffold"]))
        File.write("foo.yml", described_class.add_config("foo.yml", "foo", "bar"))
        File.write("foo.yml", described_class.add_config("foo.yml", "org", "myorg"))

        new_data = File.read("foo.yml")
        new_count = new_data.lines.grep(/^#/).size
        expect(new_count).to eq(count)

        new_data = YAML.load(new_data)
        expect(new_data['recipes']['default']).to eq(['atmos-scaffold'])
        expect(new_data['foo']).to eq('bar')
      end
    end

  end

end
