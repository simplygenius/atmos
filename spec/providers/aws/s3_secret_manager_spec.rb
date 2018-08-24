require 'simplygenius/atmos/providers/aws/s3_secret_manager'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe S3SecretManager do

          let(:manager) { described_class.new(nil) }

          before(:all) do
            @orig_stub_responses = ::Aws.config[:stub_responses]
            ::Aws.config[:stub_responses] = true
          end

          after(:all) do
            ::Aws.config[:stub_responses] = @orig_stub_responses
          end

          around(:each) do |ex|
            within_construct do |c|
              @c = c
              c.file('config/atmos.yml', YAML.dump(
                  'providers' => {
                      'aws' => {
                          'secret' => {
                              'bucket' => 'mybucket'
                          }
                      }
                  }
              ))
              Atmos.config = Config.new("ops")
              ex.run
              Atmos.config = nil
            end
          end

          describe "bucket" do

            it "uses bucket from config" do
              bucket = ::Aws::S3::Bucket.new('mybucket')
              expect(::Aws::S3::Bucket).to receive(:new).with('mybucket').and_return(bucket)
              manager.send(:bucket)
            end

            it "fails when no bucket" do
              @c.file('config/atmos.yml', YAML.dump(
                  'providers' => {
                      'aws' => {
                          'secret' => {
                          }
                      }
                  }
              ))
              Atmos.config = Config.new("ops")
              expect { manager.send(:bucket) }.to raise_error(ArgumentError, /bucket is not set/)
            end

          end

          describe "get" do

            it "gets a secret" do
              client = ::Aws::S3::Client.new
              stub = client.stub_data(:get_object)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(body: 'bar')
              ::Aws.config[:s3] = {
                stub_responses: {
                  get_object: stub
                }
              }

              expect(manager.get("foo")).to eq("bar")
            end

          end

          describe "set" do

            it "sets a secret" do
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_object).and_call_original

              manager.set("foo", "bar")
            end

          end

          describe "to_h" do

            it "gets all secrets" do
              client = ::Aws::S3::Client.new
              stub = client.stub_data(:get_object)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(body: 'bar')
              ::Aws.config[:s3] = {
                stub_responses: {
                    list_objects: { contents: [
                        {key: 'foo', storage_class: "STANDARD"},
                        {key: 'baz', storage_class: "STANDARD"}
                    ]},
                    get_object: [stub.deep_merge(body: 'bar'), stub.deep_merge(body: 'boo')]
                }
              }

              expect(manager.to_h).to eq("foo" => "bar", "baz" => "boo")
            end

          end

          describe "delete" do

            it "deletes a secret" do
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:delete_object).and_call_original

              manager.delete("foo")
            end

          end


        end

      end
    end
  end
end
