require_relative '../atmos'
require 'singleton'
require 'rotp'

module SimplyGenius
  module Atmos

    class Otp
      include Singleton
      include GemLogger::LoggerSupport

      def initialize
        @scoped_path = "atmos.otp.#{Atmos.config[:org]}"
        Atmos.config[@scoped_path] ||= {}
        @scoped_secret_store = Atmos.config[@scoped_path]
      end

      def add(name, secret)
        old = @scoped_secret_store[name]
        logger.info "Replacing OTP secret #{name}=#{old}" if old
        @scoped_secret_store[name] = secret
      end

      def remove(name)
        old = @scoped_secret_store.delete(name)
        @otp.try(:delete, name)
        logger.info "Removed OTP secret #{name}=#{old}" if old
      end

      def save
        data = SettingsHash.new
        data.notation_put(@scoped_path, @scoped_secret_store)
        Atmos.config.save_user_config_file(data)
      end

      def generate(name)
        otp(name).try(:now)
      end

      private

      def otp(name)
        @otp ||= {}
        @otp[name] ||= begin
          secret =  @scoped_secret_store[name]
          totp = nil
          if secret
            totp = ROTP::TOTP.new(secret)
          else
            logger.debug "OTP secret does not exist for '#{name}'"
          end
          totp
        end
      end

    end

  end
end
