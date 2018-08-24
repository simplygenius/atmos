require 'simplygenius/atmos/provider_factory'
require 'simplygenius/atmos/providers/aws/provider'

module SimplyGenius
  module Atmos

    describe ProviderFactory do

      describe "get" do

        it "gets the aws provider" do
          provider = described_class.get('aws')
          expect(provider).to be_a_kind_of(Providers::Aws::Provider)
        end

      end

    end

  end
end
