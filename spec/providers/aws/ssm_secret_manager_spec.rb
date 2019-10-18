require 'simplygenius/atmos/providers/aws/ssm_secret_manager'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        describe SsmSecretManager do

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
                              'type' => 'ssm'
                          }
                      }
                  }
              ))
              Atmos.config = Config.new("ops")
              ex.run
              Atmos.config = nil
            end
          end

          describe "param_name" do

            it "adds no prefix when unset" do
              Atmos.config[:secret][:prefix] = ""
              expect(manager.send(:param_name, "foo")).to eq("/foo")
            end

            it "ensures single leading slash for key" do
              Atmos.config[:secret][:prefix] = ""
              expect(manager.send(:param_name, "foo")).to eq("/foo")
              expect(manager.send(:param_name, "/foo")).to eq("/foo")
            end

            it "adds prefix when set" do
              Atmos.config[:secret][:prefix] = "/path/prefix"
              expect(manager.send(:param_name, "foo")).to eq("/path/prefix/foo")
              expect(manager.send(:param_name, "/foo")).to eq("/path/prefix/foo")
            end

            it "handles prefix with trailing slash" do
              Atmos.config[:secret][:prefix] = "/path/prefix/"
              expect(manager.send(:param_name, "foo")).to eq("/path/prefix/foo")
              expect(manager.send(:param_name, "/foo")).to eq("/path/prefix/foo")
            end

            it "ensures leading slash for prefix when set" do
              Atmos.config[:secret][:prefix] = "path/prefix"
              expect(manager.send(:param_name, "foo")).to eq("/path/prefix/foo")
            end

          end

          describe "get" do

            it "gets a secret" do
              client = ::Aws::SSM::Client.new(stub_responses: true)
              stub = client.stub_data(:get_parameter)
              stub = SymbolizedMash.new(stub.to_h).deep_merge(parameter: {value: 'bar'})
              client.stub_responses(:get_parameter, stub)

              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(manager.get("foo")).to eq("bar")
            end

            it "uses prefix to get a secret" do
              Atmos.config[:secret][:prefix] = "path/prefix"
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:get_parameter).with(hash_including(name: "/path/prefix/foo")).and_call_original

              expect(manager.get("foo"))
            end

          end

          describe "set" do

            it "sets a secret" do
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_parameter).with(hash_including(name: "/foo", value: "bar")).and_call_original

              manager.set("foo", "bar")
            end

            it "fails if secret exists" do
              # cant figure out how to stub failure on exist, so just verifying
              # that default for overwrite is false
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_parameter).with(hash_including(name: "/foo", value: "bar", overwrite: false)).and_call_original

              manager.set("foo", "bar")
            end

            it "can force if secret exists" do
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_parameter).with(hash_including(name: "/foo", value: "bar", overwrite: true)).and_call_original

              manager.set("foo", "bar", force: true)
            end


            it "uses prefix to set a secret" do
              Atmos.config[:secret][:prefix] = "/path/"
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:put_parameter).with(hash_including(name: "/path/foo", value: "bar")).and_call_original

              manager.set("foo", "bar")
            end

          end

          describe "to_h" do

            it "gets secrets" do
              client = ::Aws::SSM::Client.new(stub_responses: true)
              client.stub_responses(:get_parameters_by_path, parameters: [
                  {name: '/foo', value: 'bar'},
                  {name: '/baz', value: 'boo'}
              ])
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)

              expect(manager.to_h).to eq("foo" => "bar", "baz" => "boo")
            end

            it "paginates secrets" do
              client = ::Aws::SSM::Client.new(stub_responses: true)
              client.stub_responses(:get_parameters_by_path, [
                  {
                      parameters: [
                          {name: '/foo', value: 'bar'},
                          {name: '/baz', value: 'boo'}
                      ],
                      next_token: 'nextpage'
                  },
                  {
                      parameters: [
                          {name: '/bum', value: 'dum'},
                          {name: '/hum', value: 'sum'}
                      ]
                  }
              ])
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)

              expect(manager.to_h).to eq("baz"=>"boo", "bum"=>"dum", "foo"=>"bar", "hum"=>"sum")
            end

            it "uses prefix to restrict all secrets" do
              Atmos.config[:secret][:prefix] = "prefix/path"
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:get_parameters_by_path).with(hash_including(path: "/prefix/path/")).and_call_original

              manager.to_h
            end

            it "removes prefix from keys when set" do
              Atmos.config[:secret][:prefix] = "path/"
              client = ::Aws::SSM::Client.new(stub_responses: true)
              client.stub_responses(:get_parameters_by_path, parameters: [
                  {name: '/path/foo', value: 'bar'},
                  {name: '/path/baz', value: 'boo'}
              ])
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)

              expect(manager.to_h.keys).to eq(["foo", "baz"])
            end

          end

          describe "delete" do

            it "deletes a secret" do
              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:delete_parameter).with(hash_including(name: "/foo")).and_call_original

              manager.delete("foo")
            end

            it "uses prefix to delete a secret" do
              Atmos.config[:secret][:prefix] = "path/"

              client = ::Aws::SSM::Client.new(stub_responses: true)
              expect(::Aws::SSM::Client).to receive(:new).and_return(client)
              expect(client).to receive(:delete_parameter).with(hash_including(name: "/path/foo")).and_call_original

              manager.delete("foo")
            end

          end


        end

      end
    end
  end
end
