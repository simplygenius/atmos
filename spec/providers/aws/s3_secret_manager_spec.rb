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
                              'type' => 's3',
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

              # TODO: not sure why this breaks stubbed response
              # expect(::Aws::S3::Client).to receive(:new).and_return(client)
              # expect(client).to receive(:get_object).with(hash_including(key: "foo")).and_call_original

              expect(manager.get("foo")).to eq("bar")
            end

            it "uses prefix to get a secret" do
              Atmos.config[:secret][:prefix] = "path/"
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:get_object).with(hash_including(key: "path/foo")).and_call_original

              expect(manager.get("foo"))
            end

          end

          describe "set" do

            it "sets a secret" do
              ::Aws.config[:s3] = {
                  stub_responses: {
                      head_object: { status_code: 404, headers: {}, body: '', }
                  }
              }
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_object).with(hash_including(key: "foo")).and_call_original
              manager.set("foo", "bar")
            end

            it "fails if secret exists" do
              ::Aws.config[:s3] = {
                  stub_responses: {
                      head_object: { status_code: 200, headers: {}, body: '', }
                  }
              }
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to_not receive(:put_object)
              expect { manager.set("foo", "bar") }.to raise_error(RuntimeError, /already exists/)
            end

            it "can force if secret exists" do
              ::Aws.config[:s3] = {
                  stub_responses: {
                      head_object: { status_code: 200, headers: {}, body: '', }
                  }
              }
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_object).with(hash_including(key: "foo")).and_call_original
              manager.set("foo", "bar", force: true)
            end

            it "uses prefix to set a secret" do
              ::Aws.config[:s3] = {
                  stub_responses: {
                      head_object: { status_code: 404, headers: {}, body: '', }
                  }
              }
              Atmos.config[:secret][:prefix] = "path/"
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_object).with(hash_including(key: "path/foo")).and_call_original

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
                      list_objects_v2: { contents: [
                          {key: 'foo', storage_class: "STANDARD"},
                          {key: 'baz', storage_class: "STANDARD"}
                      ]},
                      get_object: [stub.deep_merge(body: 'bar'), stub.deep_merge(body: 'boo')]
                  }
              }

              # TODO: not sure why this breaks stubbed response
              # expect(::Aws::S3::Client).to receive(:new).and_return(client)
              # expect(client).to receive(:list_objects).with(hash_including(prefix: "")).and_call_original

              expect(manager.to_h).to eq("foo" => "bar", "baz" => "boo")
            end

            it "uses prefix to restrict all secrets" do
              Atmos.config[:secret][:prefix] = "path/"
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:list_objects_v2).with(hash_including(prefix: "path/")).and_call_original

              manager.to_h
            end

            it "removes prefix from keys when set" do
              Atmos.config[:secret][:prefix] = "path/"
              client = ::Aws::S3::Client.new
              stub = client.stub_data(:get_object)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(body: 'bar')
              ::Aws.config[:s3] = {
                  stub_responses: {
                      list_objects_v2: { contents: [
                          {key: 'path/foo', storage_class: "STANDARD"},
                          {key: 'path/baz', storage_class: "STANDARD"}
                      ]},
                      get_object: [stub.deep_merge(body: 'bar'), stub.deep_merge(body: 'boo')]
                  }
              }

              expect(manager.to_h.keys).to eq(["foo", "baz"])
            end

          end

          describe "delete" do

            it "deletes a secret" do
              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:delete_object).with(hash_including(key: "foo")).and_call_original

              manager.delete("foo")
            end

            it "uses prefix to delete a secret" do
              Atmos.config[:secret][:prefix] = "path/"

              client = ::Aws::S3::Client.new
              expect(::Aws::S3::Client).to receive(:new).and_return(client)
              expect(client).to receive(:delete_object).with(hash_including(key: "path/foo")).and_call_original

              manager.delete("foo")
            end

          end


        end

      end
    end
  end
end
