require 'simplygenius/atmos/providers/aws/auth_manager'
require 'climate_control'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe AuthManager do

          let(:manager) { described_class.new(nil) }

          before(:all) do
            @orig_stub_responses = ::Aws.config[:stub_responses]
            ::Aws.config[:stub_responses] = true
          end

          after(:all) do
            ::Aws.config[:stub_responses] = @orig_stub_responses
          end

          around(:each) do |ex|
            ::Aws.config[:sts] = nil
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
                              'assume_role_name' => 'myrole',
                              'bootstrap_assume_role_name' => 'bootrole'
                          }
                      }
                  }
              ))
              Atmos.config = Config.new("ops")
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
                              'assume_role_arn' => 'role',
                              'session_duration' => 60
                          }
                      }
                  }
              ))
              Atmos.config = Config.new("ops")
              expect(manager.send(:session_duration)).to eq(60)
            end

            it "uses default when bootstrapping from config" do
              @c.file('config/atmos.yml', YAML.dump(
                  'providers' => {
                      'aws' => {
                          'auth' => {
                              'assume_role_arn' => 'role',
                              'session_duration' => 60
                          }
                      }
                  }
              ))
              Atmos.config = Config.new("foo")
              expect(manager.send(:session_duration)).to eq(60)

              expect(manager).to receive(:assume_role).and_call_original
              manager.authenticate({}, bootstrap: true) {}

              expect(manager.send(:session_duration)).to eq(3600)
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
              result = manager.send(:assume_role, "myrole")
              expect(result).to match(hash_including(
                                          :access_key_id, :secret_access_key,
                                          :session_token, :expiration))
            end

            it "adds user_name to session name" do
              client = ::Aws::STS::Client.new
              expect(::Aws::STS::Client).to receive(:new).and_return(client)
              expect(client).to receive(:assume_role).
                  with(hash_including(duration_seconds: manager.send(:session_duration),
                                      role_session_name: "Atmos-user@name",
                                      role_arn: "myrole")).
                  and_call_original
              result = manager.send(:assume_role, "myrole", user_name: 'user@name')
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
              result = manager.send(:assume_role, "myrole", serial_number: 'myserial')
              expect(result).to be_a_kind_of(Hash)
            end

            it "passes through credentials" do
              creds_hash = {access_key_id: 'mykey', secret_access_key: 'mysecret', session_token: 'mytoken'}

              client = ::Aws::STS::Client.new
              expect(::Aws::STS::Client).to receive(:new) { |arg|
                    expect(arg).to match(hash_including(credentials: instance_of(::Aws::Credentials)))
                    expect(arg[:credentials].access_key_id).to eq('mykey')
                    expect(arg[:credentials].secret_access_key).to eq('mysecret')
                    expect(arg[:credentials].session_token).to eq('mytoken')
                  }.
                  and_return(client)
              expect(client).to receive(:assume_role).
                  with(hash_including(serial_number: 'myserial')).
                  and_call_original
              result = manager.send(:assume_role, "myrole",
                                    serial_number: 'myserial',
                                    credentials: creds_hash)
              expect(result).to be_a_kind_of(Hash)
            end

          end

          describe "authenticate" do

            describe "environment warning" do

              around(:each) do |ex|
                ClimateControl.modify('AWS_PROFILE' => nil, 'AWS_ACCESS_KEY_ID' => nil, 'AWS_SECRET_ACCESS_KEY' => nil) do
                  ex.run
                end
                ::Aws.shared_config.fresh
              end

              it "doesn't warn if environment contains profile" do
                manager.authenticate({'AWS_PROFILE' => "foo"}) {}
                expect(Logging.contents).to_not match(/No AWS credentials are active/)
              end

              it "doesn't warn if environment contains access key" do
                manager.authenticate({'AWS_ACCESS_KEY_ID' => "foo", 'AWS_SECRET_ACCESS_KEY' => 'bar'}) {}
                expect(Logging.contents).to_not match(/No AWS credentials are active/)
              end

              it "doesn't warn if a default profile is active" do
                within_construct do |c|
                  c.file("credentials", <<~EOF
                    [default]
                    aws_access_key_id = abc123
                    aws_secret_access_key = abc123
                  EOF
                  )
                  ClimateControl.modify("AWS_SHARED_CREDENTIALS_FILE" => "#{c}/credentials") do
                    ::Aws.shared_config.fresh
                    manager.authenticate({}) {}
                    expect(Logging.contents).to_not match(/No AWS credentials are active/)
                  end
                end
              end

              it "warns if environment doesn't contain auth" do
                ClimateControl.modify("AWS_SHARED_CREDENTIALS_FILE" => "/no/creds") do
                  ::Aws.shared_config.fresh
                  manager.authenticate({}) {}
                  expect(Logging.contents).to match(/No AWS credentials are active/)
                end
              end

              it "warns if environment contains profile and key" do
                manager.authenticate({'AWS_PROFILE' => "foo", 'AWS_ACCESS_KEY_ID' => "foo"}) {}
                expect(Logging.contents).to match(/Ignoring AWS_PROFILE/)
              end

            end

            it "fails if STS can't do anything" do
              ::Aws.config[:sts] = {
                stub_responses: {
                    get_caller_identity: 'ServiceError'
                }
              }

              client = ::Aws::STS::Client.new
              expect(::Aws::STS::Client).to receive(:new).and_return(client)
              expect(client).to receive(:get_caller_identity).and_call_original

              expect { manager.authenticate({}) {} }.to raise_error(SystemExit)
              expect(Logging.contents).to match(/Could not discover aws credentials/)
            end

            it "skips if STS can't do anything" do
              ::Aws.config[:sts] = {
                stub_responses: {
                    get_caller_identity: 'ServiceError'
                }
              }

              client = ::Aws::STS::Client.new
              expect(::Aws::STS::Client).to receive(:new).and_return(client)
              expect(client).to receive(:get_caller_identity).and_call_original

              expect { manager.authenticate({}) {} }.to raise_error(SystemExit)
              expect(Logging.contents).to match(/Could not discover aws credentials/)
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
              expect(Logging.contents).to match(/Account doesn't match credentials/)
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
              expect(Logging.contents).to match(/Using aws root credentials/)
            end

            it "uses simple path for bypass option" do
              expect(::Aws::STS::Client).to receive(:new).never
              Atmos.config["auth"]["bypass"] = true
              expect { |b| manager.authenticate({}, &b) }.to yield_with_args
              expect(Logging.contents).to match(/Bypassing atmos aws authentication/)
            end

            it "authenticates" do
              expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
                  to yield_with_args(
                         hash_including(
                             'AWS_ACCESS_KEY_ID',
                             'AWS_SECRET_ACCESS_KEY',
                             'AWS_SESSION_TOKEN'
                     ))
              expect(Logging.contents).to_not match(/should be supplied/)
              expect(Logging.contents).to match(/No active session cache, authenticating/)
            end

            it "saves auth cache when authenticating" do
              expect(! File.exist?(manager.send(:auth_cache_file)))
              expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
              expect(Logging.contents).to match(/No active session cache, authenticating/)
              expect(manager.send(:read_auth_cache)).to match("arnType-myrole" =>
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

              expect(File.exist?(manager.send(:auth_cache_file))).to be false
              manager.authenticate({'AWS_PROFILE' => 'profile'}) {}
              expect(File.exist?(manager.send(:auth_cache_file))).to be true
              Logging.clear

              expect(manager).to_not receive(:assume_role)
              expect(Logging.contents).to_not match(/No active session cache, authenticating/)
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


              expect(File.exist?(manager.send(:auth_cache_file))).to be false
              manager.authenticate({'AWS_PROFILE' => 'profile'}) {}
              expect(File.exist?(manager.send(:auth_cache_file))).to be true
              Logging.clear

              manager.send(:read_auth_cache)['expiration']

              expect(manager).to receive(:assume_role).
                  with(a_kind_of(String), hash_including(:user_name)).
                  and_call_original
              expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
              expect(Logging.contents).to_not match(/Session approaching expiration, renewing/)
              expect(Logging.contents).to match(/No active session cache, authenticating/)
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


              expect(File.exist?(manager.send(:auth_cache_file))).to be false
              manager.authenticate({'AWS_PROFILE' => 'profile'}) {}
              expect(File.exist?(manager.send(:auth_cache_file))).to be true
              Logging.clear
              manager.send(:read_auth_cache)['expiration']

              expect(manager).to receive(:assume_role).
                  with(a_kind_of(String),
                       hash_including(credentials: hash_including(access_key_id: 'accessKeyFromCache'))).
                  and_call_original
              expect(manager).to receive(:write_auth_cache)
              expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to yield_with_args
              expect(Logging.contents).to match(/Session approaching expiration, renewing/)
              expect(Logging.contents).to_not match(/No active session cache, authenticating/)
            end

            it "fails if mfa not setup when retrying with mfa for failed auth" do
              ::Aws.config[:sts] = {
                stub_responses: {
                    assume_role: 'AccessDenied'
                }
              }

              expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.to raise_error(SystemExit)
              expect(Logging.contents).to match(/Normal auth failed, checking for mfa/)
              expect(Logging.contents).to match(/MFA is not setup/)
            end

            it "fails if no token when prompting for mfa for failed auth" do
              ::Aws.config[:iam] = {
                stub_responses: {
                    list_mfa_devices: {
                        mfa_devices: [
                            {serial_number: 'xyz', user_name: 'foo', enable_date: Time.now}
                        ]
                    }
                }
              }

              ::Aws.config[:sts] = {
                stub_responses: {
                    assume_role: 'AccessDenied',
                }
              }

              simulate_stdin("") {
                expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
                    to output(/Enter token to retry with mfa:/).to_stdout.
                        and raise_error(SystemExit)
              }
              expect(Logging.contents).to match(/Normal auth failed, checking for mfa/)
              expect(Logging.contents).to match(/A MFA token must be supplied/)
            end

            it "retries with provided mfa token" do
              ::Aws.config[:iam] = {
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
                        with(a_kind_of(String), hash_including(:user_name)).
                        and_call_original
              expect(manager).to receive(:assume_role).
                        with(a_kind_of(String), hash_including(token_code: "123456")).
                        and_call_original
              expect(manager).to receive(:write_auth_cache)

              simulate_stdin("123456") {
                expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
                    to output(/Enter token to retry with mfa:/).to_stdout.
                           and yield_with_args
              }
              expect(Logging.contents).to match(/Normal auth failed, checking for mfa/)
            end

            it "uses integrate mfa token if available" do
              ::Aws.config[:iam] = {
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
                        with(a_kind_of(String), hash_including(:user_name)).
                        and_call_original
              expect(manager).to receive(:assume_role).
                        with(a_kind_of(String), hash_including(token_code: "123456")).
                        and_call_original
              expect(manager).to receive(:write_auth_cache)
              expect(Otp.instance).to receive(:generate).and_return("123456")

              expect { |b| manager.authenticate({'AWS_PROFILE' => 'profile'}, &b) }.
                  to yield_with_args
              expect(Logging.contents).to match(/Used integrated atmos mfa/)
            end

            describe "role_name" do

              it "gets default role from config" do
                expect(manager).to receive(:assume_role).
                    with(/^arn:.*\/myrole$/, hash_including(:user_name)).
                    and_call_original
                manager.authenticate({}) {}
              end

              it "gets role from opts" do
                expect(manager).to receive(:assume_role).
                    with(/^arn:.*\/optrole$/, hash_including(:user_name)).
                    and_call_original
                manager.authenticate({}, role: 'optrole') {}
              end

              it "uses correct role when bootstrapping ops" do
                expect(manager).to receive(:assume_role).
                    with(/^arn:.*\/myrole$/, hash_including(:user_name)).
                    and_call_original
                manager.authenticate({}, bootstrap: true) {}
              end

              it "uses correct role when bootstrapping not-ops" do
                allow(Atmos.config).to receive(:atmos_env).and_return("dev")
                expect(manager).to receive(:assume_role).
                    with(/^arn:.*\/bootrole$/, hash_including(:user_name)).
                    and_call_original
                manager.authenticate({}, bootstrap: true) {}
              end

            end

          end

        end

      end
    end
  end
end
