require_relative 'base_command'
require_relative '../../atmos/otp'
require 'clipboard'

module Atmos::Commands

  class Otp < BaseCommand

    def self.description
      "Generates an otp token for the given user"
    end

    option ["-s", "--secret"],
           'SECRET', "The otp secret\nWill save for future use"

    option ["-c", "--clipboard"],
           :flag,
           <<~EOF
            Automatically copy the token to the system
            clipboard.  For dependencies see:
            https://github.com/janlelis/clipboard
            EOF

    parameter "NAME",
              "The otp name (IAM username)"

    def execute
      code = nil
      if secret
        Atmos::Otp.instance.add(name, secret)
        code = Atmos::Otp.instance.generate(name)
        Atmos::Otp.instance.save
      else
        code = Atmos::Otp.instance.generate(name)
      end

      if code.nil?
        signal_usage_error <<~EOF
          No otp secret has been setup for #{name}
          Use the -m flag to 'atmos user create' to create/activate one
          or associate an existing secret with 'atmos otp -s <secret> <name>'
        EOF
      else
        puts code
      end

      if clipboard?
        Clipboard.copy(code)
      end
    end

  end

end
