require 'simplygenius/atmos/providers/none/secret_manager'

module SimplyGenius
  module Atmos
    module Providers
      module None

        describe SecretManager do

          let(:manager) { described_class.new(nil) }

          describe "get" do

            it "gets and sets a secret" do
              manager.set("foo", "bar")
              expect(manager.get("foo")).to eq("bar")
            end

          end

          describe "set" do

            it "fails if secret exists" do
              manager.set("foo", "bar")
              expect { manager.set("foo", "bar") }.to raise_error(RuntimeError, /already exists/)
            end

            it "can force if secret exists" do
              manager.set("foo", "bar")
              manager.set("foo", "bar", force: true)
            end

          end

          describe "to_h" do

            it "gets all secrets" do
              manager.set("foo", "bar")
              manager.set("baz", "boo")

              expect(manager.to_h).to eq("foo" => "bar", "baz" => "boo")
            end

          end

          describe "delete" do

            it "deletes a secret" do
              manager.set("foo", "bar")
              manager.delete("foo")
              expect(manager.get("foo")).to be_nil
            end

          end


        end

      end
    end
  end
end
