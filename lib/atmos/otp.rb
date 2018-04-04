require_relative '../atmos'
require 'singleton'
require 'rotp'

module Atmos

  class Otp
    include Singleton
    include GemLogger::LoggerSupport

    def initialize
      @secret_file = Atmos.config["otp.secret_file"] || "~/.atmos.yml"
      @secret_file = File.expand_path(@secret_file)
      yml_hash = YAML.load_file(@secret_file) rescue Hash.new
      @secret_store = SettingsHash.new(yml_hash)
      @secret_store[Atmos.config[:org]] ||= {}
      @secret_store[Atmos.config[:org]][:otp] ||= {}
      @scoped_secret_store = @secret_store[Atmos.config[:org]][:otp]
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
      File.write(@secret_file, YAML.dump(@secret_store.to_hash))
      File.chmod(0600, @secret_file)
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

