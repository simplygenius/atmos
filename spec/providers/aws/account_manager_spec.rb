require 'atmos/providers/aws/account_manager'

describe Atmos::Providers::Aws::AccountManager do

  let(:manager) { described_class.new(nil) }

  before(:all) do
    @orig_stub_responses = Aws.config[:stub_responses]
    Aws.config[:stub_responses] = true
  end

  after(:all) do
    Aws.config[:stub_responses] = @orig_stub_responses
  end

  before(:each) do
    allow(manager).to receive(:sleep)
  end

  describe "create_account" do

    it "creates an account for existing org" do
      org = ::Aws::Organizations::Client.new
      expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
      expect(org).to_not receive(:create_organization)

      account = manager.create_account("dev")
      expect(account).to match(hash_including(:account_id))
    end

    it "creates an account for new org" do
      Aws.config[:organizations] = {
        stub_responses: {
          describe_organization: 'AWSOrganizationsNotInUseException'
        }
      }

      org = ::Aws::Organizations::Client.new
      expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
      expect(org).to receive(:create_organization).and_call_original

      account = manager.create_account("dev")
      expect(account).to match(hash_including(:account_id))
    end

    it "creates an account with defaults" do
      client = Aws::Organizations::Client.new
      stub = client.stub_data(:describe_organization)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(organization: {master_account_email: 'foo@bar.com'})
      Aws.config[:organizations] = {
        stub_responses: {
          describe_organization: stub
        }
      }

      org = ::Aws::Organizations::Client.new
      expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
      expect(org).to receive(:create_account).
          with(email: "foo+dev@bar.com", account_name: "Atmos dev account").
          and_call_original

      account = manager.create_account("dev")
      expect(account).to match(hash_including(email: "foo+dev@bar.com", name: "Atmos dev account"))
    end

    it "creates an account with givens" do
      org = ::Aws::Organizations::Client.new
      expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
      expect(org).to receive(:create_account).
          with(email: "baz@bar.com", account_name: "myname").
          and_call_original

      account = manager.create_account("dev", email:"baz@bar.com", name: "myname")
      expect(account).to match(hash_including(email: "baz@bar.com", name: "myname"))
    end

    it "creates an account with delayed status" do
      client = Aws::Organizations::Client.new
      stub = client.stub_data(:create_account)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(create_account_status: {state: 'in_progress'})
      Aws.config[:organizations] = {
        stub_responses: {
            create_account: stub
        }
      }

      org = ::Aws::Organizations::Client.new
      expect(::Aws::Organizations::Client).to receive(:new).and_return(org)
      expect(org).to receive(:describe_create_account_status).and_call_original

      account = manager.create_account("dev")
      expect(account).to match(hash_including(:account_id))
    end

    it "creates an account with failed status" do
      client = Aws::Organizations::Client.new
      stub = client.stub_data(:create_account)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(create_account_status: {state: 'failed'})
      Aws.config[:organizations] = {
        stub_responses: {
            create_account: stub
        }
      }

      expect { manager.create_account("dev") }.to raise_error(SystemExit)
    end

  end

end
