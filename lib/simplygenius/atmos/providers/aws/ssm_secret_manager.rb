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
            @client = ::Aws::SSM::Client.new
          end

          def set(key, value)
            opts = {}

            param_name = param_name(key)
            param_type = @encrypt ? "SecureString" : "String"
            param_value = value

            if value.is_a?(Array)
              raise "AWS SSM Parameter Store cannot encrypt lists directly" if @encrypt
              param_type = "StringList"
              param_value = value.join(",")
            end

            @client.put_parameter(name: param_name, value: param_value, type: param_type)
          end

          def get(key)
            resp = @client.get_parameter(name: param_name(key), with_decryption: @encrypt)
            resp.parameter.value
          end

          def delete(key)
            @client.delete_parameter(name: param_name(key))
          end

          def to_h
            result = {}
            resp = @client.get_parameters_by_path(path: param_name(""), recursive: true, with_decryption: @encrypt)
            resp.parameters.each do |p|
              key = p.name.gsub(/^#{param_name("")}/, '')
              result[key] = p.value
            end

            return result
          end

          private

          def param_name(key)
            param_name = "/#{@path_prefix}/#{key}"
            param_name.gsub!(/\/{2,}/, '/')
            param_name
          end

        end

      end
    end
  end
end
