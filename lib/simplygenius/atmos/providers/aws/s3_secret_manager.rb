require_relative '../../../atmos'
require 'aws-sdk-s3'

module SimplyGenius
  module Atmos
    module Providers
      module Aws

        class S3SecretManager
          include GemLogger::LoggerSupport

          def initialize(provider)
            @provider = provider
            @bucket_name = Atmos.config[:secret][:bucket]
            @bucket_prefix = "#{Atmos.config[:secret][:prefix]}"
            @encrypt = Atmos.config[:secret][:encrypt]
          end

          def set(key, value)
            opts = {}
            opts[:server_side_encryption] = "AES256" if @encrypt
            bucket.object(@bucket_prefix + key).put(body: value, **opts)
          end

          def get(key)
            bucket.object(@bucket_prefix + key).get.body.read
          end

          def delete(key)
            bucket.object(@bucket_prefix + key).delete
          end

          def to_h
            Hash[bucket.objects(prefix: @bucket_prefix).collect {|o|
              key = o.key
              if @bucket_prefix.present?
                key = o.key.gsub(/^#{@bucket_prefix}/, '')
              end
              [key, o.get.body.read]
            }]
          end

          private

          def bucket
            raise ArgumentError.new("The s3 secret bucket is not set") unless @bucket_name
            @bucket ||= ::Aws::S3::Bucket.new(@bucket_name)
          end

        end

      end
    end
  end
end
