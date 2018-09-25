require 'simplygenius/atmos/otp'

module SimplyGenius
  module Atmos

    describe Otp do

      let(:otp) { described_class.send(:new) }

      around(:each) do |ex|
        Atmos.config = Config.new("ops")
        @config = SettingsHash.new
        @config[:org] = "myorg"
        Atmos.config.instance_variable_set(:@config, @config)

        ex.run
        Atmos.config = nil
      end

      describe "initialize" do

        it "has a default secret file" do
          @config.notation_put("atmos.otp.secret_file", nil)
          expect(otp.instance_variable_get(:@secret_file)).to eq(File.expand_path("~/.atmos.yml"))
        end

        it "can override secret file" do
          @config.notation_put("atmos.otp.secret_file", "~/.foo.yml")
          expect(otp.instance_variable_get(:@secret_file)).to eq(File.expand_path("~/.foo.yml"))
        end

        it "is a singleton" do
          expect(described_class.instance).to eq(described_class.instance)
        end

      end

      describe "usage" do

        it "returns nil for non-existant key name" do
          expect(otp.generate("foo")).to be_nil
        end

        it "can add name and and generate for it" do
          otp.add("foo", "secret")
          expect(otp.generate("foo")).to match(/[0-9]{6}/)
        end

        it "can remove name" do
          otp.add("foo", "secret")
          expect(otp.generate("foo")).to match(/[0-9]{6}/)
          otp.remove("foo")
          expect(otp.generate("foo")).to be_nil
        end

      end

      describe "save" do

        it "saves secret file" do
          within_construct do |c|
            secret_file = "#{c}/foo.yml"
            @config.notation_put("atmos.otp.secret_file", secret_file)
            otp.add("foo", "sekret")

            expect(File.exist?(secret_file)).to be false
            otp.save
            expect(File.exist?(secret_file)).to be true
            data = YAML.load_file(secret_file)
            expect(data["myorg"]["otp"]["foo"]).to eq("sekret")
          end
        end

        it "loads secret file" do
          within_construct do |c|
            secret_file = "#{c}/foo.yml"
            @config.notation_put("atmos.otp.secret_file", secret_file)
            otp.add("foo", "sekret")
            otp.save
            expect(File.exist?(secret_file)).to be true
            otp = described_class.send(:new)
            expect(otp.generate("foo")).to match(/[0-9]{6}/)
          end
        end

      end

    end

  end
end
