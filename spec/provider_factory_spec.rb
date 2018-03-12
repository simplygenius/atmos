require 'atmos/provider_factory'
require 'atmos/providers/aws/provider'

describe Atmos::ProviderFactory do

  describe "get" do

    it "gets the aws provider" do
      provider = Atmos::ProviderFactory.get('aws')
      expect(provider).to be_a_kind_of(Atmos::Providers::Aws::Provider)
    end

  end

end
