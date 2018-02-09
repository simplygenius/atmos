require 'atmos/utils'

describe Atmos::Utils do

  describe "clean_indent" do

    it "handles empty string" do
      str = ""
      expect(Atmos::Utils.clean_indent(str)).to eq("")
    end

    it "uses first non-empty for pattern" do
      str = <<-EOF

        foo
          bar
      EOF
      expect(Atmos::Utils.clean_indent(str)).to eq("\nfoo\n  bar\n")
    end

    it "skips empty lines" do
      str = <<-EOF
        foo

        bar
      EOF
      expect(Atmos::Utils.clean_indent(str)).to eq("foo\n\nbar\n")
    end

    it "uses the indentation for a here doc" do
      str = <<-EOF
        foo
          bar
            baz
        bum
      EOF
      expect(Atmos::Utils.clean_indent(str)).to eq("foo\n  bar\n    baz\nbum\n")
    end

  end

end
