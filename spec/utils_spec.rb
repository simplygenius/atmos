require 'simplygenius/atmos/utils'

module SimplyGenius
  module Atmos

    describe Utils do

      describe "clean_indent" do

        it "handles empty string" do
          str = ""
          expect(described_class.clean_indent(str)).to eq("")
        end

        it "uses first non-empty for pattern" do
          str = <<-EOF
            
            foo
              bar
          EOF
          expect(described_class.clean_indent(str)).to match(/\s*\nfoo\n  bar\n/)
        end

        it "skips empty lines" do
          str = <<-EOF
            foo
            
            bar
          EOF
          expect(described_class.clean_indent(str)).to match(/foo\n\s*\nbar\n/)
        end

        it "uses the indentation for a here doc" do
          str = <<-EOF
            foo
              bar
                baz
            bum
          EOF
          expect(described_class.clean_indent(str)).to match(/foo\n  bar\n    baz\nbum\n/)
        end

      end

    end

  end
end
