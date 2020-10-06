require 'simplygenius/atmos/providers/none/auth_manager'

module SimplyGenius
  module Atmos
    module Providers
      module None

        describe AuthManager do

          let(:manager) { described_class.new(nil) }

          describe "authenticate" do

            it "authenticates" do
              expect { |b| manager.authenticate({'FOO' => 'bar'}, &b) }.
                  to yield_with_args(
                         hash_including(
                             'FOO'
                     ))
              expect(Logging.contents).to match(/Calling none authentication target/)
            end

          end

        end

      end
    end
  end
end
