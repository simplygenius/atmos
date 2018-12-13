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

        it "is a singleton" do
          expect(described_class.instance).to eq(described_class.instance)
        end

        it "handles empty secrets" do
          expect(otp.instance_variable_get(:@scoped_secret_store)).to eq({})
        end

        it "sees scoped existing secrets" do
          @config.notation_put("atmos.otp.myorg.foo", "bar")
          @config.notation_put("atmos.otp.otherorg.bar", "bum")
          expect(otp.instance_variable_get(:@scoped_secret_store)).to eq({"foo" => "bar"})
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
            allow(Atmos.config).to receive(:user_config_file).and_return(secret_file)

            otp.add("foo", "sekret")

            expect(File.exist?(secret_file)).to be false
            otp.save
            expect(File.exist?(secret_file)).to be true
            data = YAML.load_file(secret_file)
            expect(data["atmos"]["otp"]["myorg"]["foo"]).to eq("sekret")
          end
        end

      end

    end

  end
end
