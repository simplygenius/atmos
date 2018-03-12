require 'atmos/providers/aws/user_manager'

describe Atmos::Providers::Aws::UserManager do

  let(:manager) { described_class.new(nil) }

  before(:all) do
    @orig_stub_responses = Aws.config[:stub_responses]
    Aws.config[:stub_responses] = true
  end

  after(:all) do
    Aws.config[:stub_responses] = @orig_stub_responses
  end

  describe "create_user" do

    it "creates a user" do
      user = manager.create_user("foo@bar.com", [])
      expect(user).to match(hash_including(user_name: "foo@bar.com"))
    end

    it "creates a user with groups" do
      user = manager.create_user("foo@bar.com", ["g1", "g2"])
      expect(user).to match(hash_including(user_name: "foo@bar.com", groups: ["g1", "g2"]))
    end

    it "creates a user with login" do
      user = manager.create_user("foo@bar.com", [], login: true)
      expect(user).to match(hash_including(user_name: "foo@bar.com", password: anything))
    end

    it "creates a user with access keys" do
      user = manager.create_user("foo@bar.com", [], keys: true)
      expect(user).to match(hash_including(user_name: "foo@bar.com", key: anything, secret: anything))
    end

    it "creates a user with ssh public key" do
      user = manager.create_user("foo@bar.com", [], public_key: "mykey")
      expect(user).to match(hash_including(user_name: "foo@bar.com"))
    end

  end

  describe "modify_groups" do

    it "does nothing for no groups" do
      user = manager.modify_groups("foo@bar.com", [])
      expect(user).to match(hash_including(groups: []))
    end

    it "adds a group" do
      client = Aws::IAM::Client.new
      group_stub = client.stub_data(:get_group)
      group_stub = SymbolizedMash.new(group_stub.to_h).deep_merge(group: {group_name: 'g1'})

      Aws.config[:iam] = {
        stub_responses: {
          list_groups_for_user: {groups: [group_stub[:group]]}
        }
      }

      user = manager.modify_groups("foo@bar.com", ["g2"], add: true)
      expect(user).to match(hash_including(groups: ["g1", "g2"]))
    end

    it "replaces group" do
      client = Aws::IAM::Client.new
      group_stub = client.stub_data(:get_group)
      group_stub = SymbolizedMash.new(group_stub.to_h).deep_merge(group: {group_name: 'g1'})

      Aws.config[:iam] = {
        stub_responses: {
          list_groups_for_user: {groups: [group_stub[:group]]}
        }
      }

      user = manager.modify_groups("foo@bar.com", ["g2"], add: false)
      expect(user).to match(hash_including(groups: ["g2"]))
    end

  end

end
