require "simplygenius/atmos/plugins/json_diff"

module SimplyGenius
  module Atmos
    module Plugins

      describe JsonDiff do

        let(:plugin) { described_class.new({}) }

        it 'should pass through data in filter' do
          expect(plugin.filter("foo\n")).to eq("foo\n")
        end

        it 'should detect start of json' do
          plugin.filter("stuff\n")
          plugin.filter(%Q(bar: "[{))
          expect(plugin.instance_variable_get(:@plan_detected)).to eq(false)
          expect(plugin.instance_variable_get(:@json_data)).to eq("")
          plugin.filter("before\nTerraform will perform the following actions:\nblah\n")
          plugin.filter(%Q(foo: "[{))
          expect(plugin.instance_variable_get(:@plan_detected)).to eq(true)
          expect(plugin.instance_variable_get(:@json_data)).to eq(%Q(foo: "[{))
        end

        it 'should detect end of json and insert a diff' do
          output = ""
          output << plugin.filter("Terraform will perform the following actions:\nblah\n")
          output << plugin.filter(%Q(foo: "[{))
          expect(plugin.instance_variable_get(:@json_data)).to_not eq("")

          output << plugin.filter(%Q(\\"foo\\": \\"bar\\"}]" => "[{\\"foo\\": \\"baz\\"}]"\n))
          expect(plugin.instance_variable_get(:@json_data)).to eq("")
          expect(output).to eq <<~EOF
            Terraform will perform the following actions:
            blah
            foo: 
             [
               {
            -    "foo": "bar"
            +    "foo": "baz"
               }
             ]
            

          EOF
        end

        it 'should not swallow output when no end of json detected' do
          output = ""
          output << plugin.filter("Terraform will perform the following actions:\nblah\n")
          output << plugin.filter(%Q(foo: "[{\n))
          expect(plugin.instance_variable_get(:@json_data)).to_not eq("")
          output << plugin.filter("", flushing: true)
          expect(output).to eq <<~EOF
            Terraform will perform the following actions:
            blah
            foo: "[{
          EOF
        end

        it 'should handle embedded newlines' do
          output = ""
          output << plugin.filter("Terraform will perform the following actions:\nblah\n")
          output << plugin.filter(%Q(foo: "[{))
          expect(plugin.instance_variable_get(:@json_data)).to_not eq("")

          output << plugin.filter(%Q(\\"foo\\": \\"bar\\"}]\n\\n" => "[{\\"foo\\": \\"baz\\"}]\\n\n"\n))
          expect(plugin.instance_variable_get(:@json_data)).to eq("")

          expect(output).to eq <<~EOF
            Terraform will perform the following actions:
            blah
            foo: 
             [
               {
            -    "foo": "bar"
            +    "foo": "baz"
               }
             ]
            

          EOF
        end

        it 'should handle }]" at end of line' do
          output = ""
          output << plugin.filter("Terraform will perform the following actions:\nblah\n")
          output << plugin.filter(%Q(foo: "[{))
          output << plugin.filter(%Q(\\"foo\\": \\"bar]\\"))
          output << plugin.filter(%Q(}]\n\\n" => "[{\\"foo\\": \\"baz}\\"))
          output << plugin.filter(%Q(}]\\n\n"\n))
          expect(output).to eq <<~EOF
            Terraform will perform the following actions:
            blah
            foo: 
             [
               {
            -    "foo": "bar]"
            +    "foo": "baz}"
               }
             ]
            

          EOF
        end

        it 'should fail gracefully when unable to parse json' do
          output = ""
          output << plugin.filter("Terraform will perform the following actions:\nblah\n")
          output << plugin.filter(%Q(foo: "[{\\"foo\\": \\"bar\\"}\n\\n" => "[{\\"foo\\": \\"baz\\"}]\\n\n"\n))
          expect(Logging.contents).to match(/Failed to parse JSON/)
          expect(output).to eq "Terraform will perform the following actions:\nblah\nfoo: \n\n[{\\\"foo\\\": \\\"bar\\\"}\n\n=>\n\n[{\\\"foo\\\": \\\"baz\\\"}]\n\n\n"
        end

      end

    end
  end
end
