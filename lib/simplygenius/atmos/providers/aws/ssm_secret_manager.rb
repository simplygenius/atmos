require_relative '../../../atmos'
require 'aws-sdk-ssm'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        class SsmSecretManager
          include GemLogger::LoggerSupport

          def initialize(provider)
            @provider = provider
            @path_prefix = "#{Atmos.config[:secret][:prefix]}"
            @encrypt = Atmos.config[:secret][:encrypt]
          end

          def set(key, value, force: false)
            opts = {}

            param_name = param_name(key)
            param_type = @encrypt ? "SecureString" : "String"
            param_value = value

            if value.is_a?(Array)
              raise "AWS SSM Parameter Store cannot encrypt lists directly" if @encrypt
              param_type = "StringList"
              param_value = value.join(",")
            end

            client.put_parameter(name: param_name, value: param_value, type: param_type, overwrite: force)
          end

          def get(key)
            resp = client.get_parameter(name: param_name(key), with_decryption: @encrypt)
            resp.parameter.value
          end

          def delete(key)
            client.delete_parameter(name: param_name(key))
          end

          def to_h
            result = {}
            next_token = nil
            loop do
              # max_results can't be greater than 10, which is the default
              resp = client.get_parameters_by_path(path: param_name(""),
                                                   next_token: next_token,
                                                   recursive: true, with_decryption: @encrypt)
              resp.parameters.each do |p|
                key = p.name.gsub(/^#{param_name("")}/, '')
                result[key] = p.value
              end

              next_token = resp.next_token
              break if next_token.nil?
            end

            return result
          end

          private

          def param_name(key)
            param_name = "/#{@path_prefix}/#{key}"
            param_name.gsub!(/\/{2,}/, '/')
            param_name
          end

          def client
            @client ||= ::Aws::SSM::Client.new
          end
        end

      end
    end
  end
end
