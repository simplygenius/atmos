require "simplygenius/atmos/commands/otp"

module SimplyGenius
  module Atmos
    module Commands

      describe Otp do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "execute" do

          before(:each) do
            Otp.instance_variable_set(:@singleton__instance__, nil)
          end

          it "fails for invalid name" do
            expect{cli.run(["newkey"])}.to raise_error(Clamp::UsageError, /No otp secret/)
          end

          it "works for existing name" do
            Atmos::Otp.instance.add("newkey", "secret")
            expect(Clipboard).to_not receive(:copy)
            expect{cli.run(["newkey"])}.to output(/\d{6}/).to_stdout
          end

          it "can copy to clipboard for existing name" do
            Atmos::Otp.instance.add("newkey", "secret")
            expect(Clipboard).to receive(:copy)
            expect{cli.run(["-c", "newkey"])}.to output(/\d{6}/).to_stdout
          end

          it "can save given key" do
            expect(Atmos::Otp.instance).to receive(:save)
            expect{cli.run(["-s", "sekret", "newkey"])}.to output(/\d{6}/).to_stdout
          end

        end

      end

    end
  end
end
