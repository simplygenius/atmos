require 'atmos'
require 'clamp'
require 'climate_control'
require 'yaml'

module Atmos::Commands

  class User < Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      "Manages users in the cloud provider"
    end

    subcommand "create", "Create a new user" do

      option ["-l", "--login"],
             :flag, "generate a login password\n",
             default: true

      option ["-k", "--key"],
             :flag, "create access keys\n",
             default: false

      option ["-p", "--public-key"],
             "PUBLIC_KEY", "add ssh public key\n"

      option ["-g", "--group"],
             "GROUP",
             "associate the given groups to new user\n",
             multivalued: true,
             default: ["all-users"]

      parameter "USERNAME",
                "The username of the user to add\nShould be an email address" do |u|
        raise ArgumentError.new("Not an email") if u !~ URI::MailTo::EMAIL_REGEXP
        u
      end

      def execute

        Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
          ClimateControl.modify(auth_env) do
            user = Atmos.config.provider.user_manager.create_user(username, group_list,
                                                           login: login?, keys: key?,
                                                           public_key: public_key)
            display = YAML.dump(user).sub(/\A---\n/, "")
            logger.info "User created:\n#{display}"
          end
        end

      end

    end

    subcommand "groups", "Assign groups to existing user" do

      option ["-a", "--add"],
             :flag,
             "adds instead of replacing groups\n"
      option ["-g", "--group"],
             "GROUP",
             "associate the given groups to new user\n",
             multivalued: true,
             required: true

       parameter "USERNAME",
                 "The username of the user to modify\n"

       def execute

         Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
           ClimateControl.modify(auth_env) do
             user = Atmos.config.provider.user_manager.modify_groups(username, group_list, add: add?)
             logger.info "User modified: #{user.pretty_inspect}"
           end
         end

       end

     end

  end

end
