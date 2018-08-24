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
            logger.debug("Secrets config is: #{Atmos.config[:secret]}")
            @bucket_name = Atmos.config[:secret][:bucket]
            @encrypt = Atmos.config[:secret][:encrypt]
          end

          def set(key, value)
            opts = {}
            opts[:server_side_encryption] = "AES256" if @encrypt
            bucket.object(key).put(body: value, **opts)
          end

          def get(key)
            bucket.object(key).get.body.read
          end

          def delete(key)
            bucket.object(key).delete
          end

          def to_h
            Hash[bucket.objects.collect {|o|
              [o.key, o.get.body.read]
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
