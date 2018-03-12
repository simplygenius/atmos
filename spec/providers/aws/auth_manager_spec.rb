require 'atmos/providers/aws/auth_manager'

describe Atmos::Providers::Aws::AuthManager do

  let(:manager) { described_class.new(nil) }

  before(:all) do
    @orig_stub_responses = Aws.config[:stub_responses]
    Aws.config[:stub_responses] = true
  end

  after(:all) do
    Aws.config[:stub_responses] = @orig_stub_responses
  end

  around(:each) do |ex|
    Aws.config[:sts] = nil
    @ops_account_id = "123456789012"
    within_construct do |c|
      @c = c
      c.file('config/atmos.yml', YAML.dump(
          'environments' => {
              'ops' => {
                  'account_id' => @ops_account_id
              }
          },
          'providers' => {
              'aws' => {
                  'auth' => {
                      'assume_role_name' => 'myrole'
                  }
              }
          }
      ))
      Atmos.config = Atmos::Config.new("ops")
      ex.run
      Atmos.config = nil
    end
  end

  describe "auth_cache_file" do

    it "generates the cache filename" do
      expect(manager.send(:auth_cache_file)).
          to eq(File.join(Atmos.config.auth_cache_dir, 'aws-assume-role.json'))
    end

  end

  describe "write_auth_cache" do

    it "dumps json to file" do
      manager.send(:write_auth_cache, foo: 'bar')
      data = File.read(manager.send(:auth_cache_file))
      expect(JSON.parse(data)["foo"]).to eq("bar")
    end

  end

  describe "read_auth_cache" do

    it "dumps json to file" do
      manager.send(:write_auth_cache, foo: 'bar')
      data = manager.send(:read_auth_cache)
      expect(data["foo"]).to eq("bar")
    end

  end

  describe "session_duration" do

    it "has a default" do
      expect(manager.send(:session_duration)).to eq(3600)
    end

    it "reads from config" do
      @c.file('config/atmos.yml', YAML.dump(
          'providers' => {
              'aws' => {
                  'auth' => {
                      'assume_role_name' => 'role',
                      'session_duration' => 60
                  }
              }
          }
      ))
      Atmos.config = Atmos::Config.new("ops")
      expect(manager.send(:session_duration)).to eq(60)
    end

  end

  describe "assume_role" do

    it "uses sts to return a hash of new credentials" do
      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).and_return(client)
      expect(client).to receive(:assume_role).
          with(hash_including(duration_seconds: manager.send(:session_duration),
                              role_session_name: "Atmos",
                              role_arn: "myrole")).
          and_call_original
      result = manager.send(:assume_role)
      expect(result).to match(hash_including(
                               :access_key_id, :secret_access_key,
                               :session_token, :expiration))
    end

    it "passes through params" do
      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).and_return(client)
      expect(client).to receive(:assume_role).
          with(hash_including(serial_number: 'myserial')).
          and_call_original
      result = manager.send(:assume_role, serial_number: 'myserial')
      expect(result).to be_a_kind_of(Hash)
    end

    it "passes through credentials" do
      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).
          with(hash_including(credentials: {access_key_id: 'mykey'})).
          and_return(client)
      expect(client).to receive(:assume_role).
          with(hash_including(serial_number: 'myserial')).
          and_call_original
      result = manager.send(:assume_role,
                            serial_number: 'myserial',
                            credentials: {access_key_id: 'mykey'})
      expect(result).to be_a_kind_of(Hash)
    end

  end

  describe "authenticate" do

    it "warns if environment doesn't contain auth" do
      manager.authenticate({}) {}
      expect(Atmos::Logging.contents).to match(/should be supplied/)
    end

    it "fails if STS can't do anything" do
      Aws.config[:sts] = {
        stub_responses: {
            get_caller_identity: 'ServiceError'
        }
      }

      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).and_return(client)
      expect(client).to receive(:get_caller_identity).and_call_original

      expect { manager.authenticate({}) {} }.to raise_error(SystemExit)
      expect(Atmos::Logging.contents).to match(/Could not discover aws credentials/)
    end

    it "skips if STS can't do anything" do
      Aws.config[:sts] = {
        stub_responses: {
            get_caller_identity: 'ServiceError'
        }
      }

      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).and_return(client)
      expect(client).to receive(:get_caller_identity).and_call_original

      expect { manager.authenticate({}) {} }.to raise_error(SystemExit)
      expect(Atmos::Logging.contents).to match(/Could not discover aws credentials/)
    end

    it "fails if root credentials not for current account" do
      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).and_return(client)
      stub = client.stub_data(:get_caller_identity)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(
          arn: "arn:aws:iam::1234:root",
          account: @ops_account_id
      )
      client.stub_responses(:get_caller_identity, stub)

      expect(client).to receive(:get_caller_identity).and_call_original
      expect(manager).to_not receive(:read_auth_cache)

      expect { manager.authenticate({}) {} }.to raise_error(SystemExit)
      expect(Atmos::Logging.contents).to match(/Account doesn't match credentials/)
    end

    it "uses simple path for root credentials when present" do
      client = ::Aws::STS::Client.new
      expect(::Aws::STS::Client).to receive(:new).and_return(client)
      stub = client.stub_data(:get_caller_identity)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(
          arn: "arn:aws:iam::#{@ops_account_id}:root",
          account: @ops_account_id
      )
      client.stub_responses(:get_caller_identity, stub)

      expect(client).to receive(:get_caller_identity).and_call_original
      expect(manager).to_not receive(:read_auth_cache)

      expect { |b| manager.authenticate({}, &b) }.to yield_with_args
      expect(Atmos::Logging.contents).to match(/Using aws root credentials/)
    end

    it "authenticates" do
      expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
          to yield_with_args(
                 hash_including(
                     'AWS_ACCESS_KEY_ID',
                     'AWS_SECRET_ACCESS_KEY',
                     'AWS_SESSION_TOKEN'
             ))
      expect(Atmos::Logging.contents).to_not match(/should be supplied/)
      expect(Atmos::Logging.contents).to match(/No active session cache, authenticating/)
    end

    it "saves auth cache when authenticating" do
      expect(! File.exist?(manager.send(:auth_cache_file)))
      expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
      expect(Atmos::Logging.contents).to match(/No active session cache, authenticating/)
      expect(manager.send(:read_auth_cache)).to match(
                       hash_including(
                           'access_key_id',
                           'secret_access_key',
                           'session_token',
                           'expiration'
                   ))
    end

    it "uses auth cache instead of authenticating" do
      client = ::Aws::STS::Client.new
      allow(::Aws::STS::Client).to receive(:new).and_return(client)
      stub = client.stub_data(:assume_role)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(
          credentials: {expiration: (Time.now + 3600).utc}
      )
      client.stub_responses(:assume_role, stub)


      manager.authenticate({'AWS_PROFILE' => 'profile'}) {}
      expect(File.exist?(manager.send(:auth_cache_file)))

      expect(manager).to_not receive(:assume_role)
      expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
    end

    it "renews auth cache when expired" do
      client = ::Aws::STS::Client.new
      allow(::Aws::STS::Client).to receive(:new).and_return(client)
      stub = client.stub_data(:assume_role)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(
          credentials: {
              access_key_id: 'accessKeyFromCache',
              expiration: (Time.now - 1).utc
          }
      )
      client.stub_responses(:assume_role, stub)


      manager.authenticate({'AWS_PROFILE' => 'profile'}) {}
      expect(File.exist?(manager.send(:auth_cache_file)))
      expiration = manager.send(:read_auth_cache)['expiration']

      expect(manager).to receive(:assume_role).
          with(no_args).
          and_call_original
      expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
      expect(Atmos::Logging.contents).to_not match(/Session approaching expiration, renewing/)
      expect(Atmos::Logging.contents).to match(/No active session cache, authenticating/)
    end

    it "renews auth cache when close to expiring" do
      client = ::Aws::STS::Client.new
      allow(::Aws::STS::Client).to receive(:new).and_return(client)
      stub = client.stub_data(:assume_role)
      stub = SymbolizedMash.new(stub.to_h).deep_merge(
          credentials: {
              access_key_id: 'accessKeyFromCache',
              expiration: (Time.now + 60).utc
          }
      )
      client.stub_responses(:assume_role, stub)


      manager.authenticate({'AWS_PROFILE' => 'profile'}) {}
      expect(File.exist?(manager.send(:auth_cache_file)))
      expiration = manager.send(:read_auth_cache)['expiration']

      expect(manager).to receive(:assume_role).
          with(hash_including(credentials: hash_including(access_key_id: 'accessKeyFromCache'))).
          and_call_original
      expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
      expect(Atmos::Logging.contents).to match(/Session approaching expiration, renewing/)
    end

    it "fails if mfa not setup when retrying with mfa for failed auth" do
      Aws.config[:sts] = {
        stub_responses: {
            assume_role: 'AccessDenied'
        }
      }

      expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to raise_error(SystemExit)
      expect(Atmos::Logging.contents).to match(/Normal auth failed, checking for mfa/)
      expect(Atmos::Logging.contents).to match(/MFA is not setup/)
    end

    it "fails if no token when prompting for mfa for failed auth" do
      Aws.config[:iam] = {
        stub_responses: {
            list_mfa_devices: {
                mfa_devices: [
                    {serial_number: 'xyz', user_name: 'foo', enable_date: Time.now}
                ]
            }
        }
      }

      Aws.config[:sts] = {
        stub_responses: {
            assume_role: 'AccessDenied',
        }
      }

      simulate_stdin("") {
        expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
            to output(/Enter token to retry with mfa:/).to_stdout.
                and raise_error(SystemExit)
      }
      expect(Atmos::Logging.contents).to match(/Normal auth failed, checking for mfa/)
      expect(Atmos::Logging.contents).to match(/A MFA token must be supplied/)
    end

    it "retries with provided mfa token" do
      Aws.config[:iam] = {
        stub_responses: {
            list_mfa_devices: {
                mfa_devices: [
                    {serial_number: 'xyz', user_name: 'foo', enable_date: Time.now}
                ]
            }
        }
      }

      client = ::Aws::STS::Client.new
      allow(::Aws::STS::Client).to receive(:new).and_return(client)
      stub = client.stub_data(:assume_role)
      client.stub_responses(:assume_role, 'AccessDenied', stub)

      expect(manager).to receive(:assume_role).
                with(no_args).
                and_call_original
      expect(manager).to receive(:assume_role).
                with(hash_including(token_code: "123456")).
                and_call_original
      expect(manager).to receive(:write_auth_cache)

      simulate_stdin("123456") {
        expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
            to output(/Enter token to retry with mfa:/).to_stdout.
                   and yield_with_args
      }
      expect(Atmos::Logging.contents).to match(/Normal auth failed, checking for mfa/)
    end

  end

end
