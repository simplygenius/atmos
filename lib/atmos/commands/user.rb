require_relative 'base_command'
require 'climate_control'

module Atmos::Commands

  class User < BaseCommand

    def self.description
      "Manages users in the cloud provider"
    end

    subcommand "create", "Create a new user" do

      option ["-f", "--force"],
             :flag, "forces deletion/updates for pre-existing resources\n",
             default: false

      option ["-l", "--login"],
             :flag, "generate a login password\n",
             default: false

      option ["-m", "--mfa"],
             :flag, "setup a mfa device\n",
             default: false

      option ["-k", "--key"],
             :flag, "create access keys\n",
             default: false

      option ["-p", "--public-key"],
             "PUBLIC_KEY", "add ssh public key\n"

      option ["-g", "--group"],
             "GROUP",
             "associate the given groups to new user\n",
             multivalued: true

      parameter "USERNAME",
                "The username of the user to add\nShould be an email address" do |u|
        raise ArgumentError.new("Not an email") if u !~ URI::MailTo::EMAIL_REGEXP
        u
      end

      def execute

        Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
          ClimateControl.modify(auth_env) do
            manager = Atmos.config.provider.user_manager
            user = manager.create_user(username)
            user.merge!(manager.set_groups(username, group_list, force: force?)) if group_list.present?
            user.merge!(manager.enable_login(username, force: force?)) if login?
            user.merge!(manager.enable_mfa(username, force: force?)) if mfa?
            user.merge!(manager.enable_access_keys(username, force: force?)) if key?
            user.merge!(manager.set_public_key(username, public_key, force: force?)) if public_key.present?

            logger.info "\nUser created:\n#{display user}\n"

            if  mfa? && user[:mfa_secret]
              save_mfa = agree("Save the MFA secret for runtime integration with auth? ") {|q|
                q.default = 'y'
              }
              Atmos::Otp.instance.save if save_mfa
            end

          end
        end

      end

    end

  end

end
