require_relative '../atmos'
require_relative '../atmos/ui'
require 'clamp'
require 'sigdump/setup'

Dir.glob(File.join(File.join(__dir__, 'commands'), '*.rb')) do |f|
  require_relative "commands/#{File.basename(f).sub(/\.rb$/, "")}"
end

module SimplyGenius
  module Atmos

    # The command line interface to atmos
    class CLI < Clamp::Command

      include GemLogger::LoggerSupport

      def self.description
        desc = <<-DESC
          Atmos version #{VERSION}
    
          Runs The atmos command line application
    
          e.g.
    
          atmos --help
        DESC
        desc.split("\n").collect(&:strip).join("\n")
      end

      option ["-d", "--debug"],
             :flag, "debug output\n",
             default: false

      option ["-c", "--[no-]color"],
             :flag, "colorize output (or not)\n (default: $stdout.tty?)"

      option ["-e", "--atmos-env"],
             'ENV', "The atmos environment\n",
             environment_variable: 'ATMOS_ENV', default: 'ops'

      option ["-g", "--atmos-group"],
             'GROUP', "The atmos working group\n for selecting recipe groups\n",
             default: 'default'

      option ["-p", "--load-path"],
             "PATH", "adds additional paths to ruby load path",
             multivalued: true

      def default_color?
         $stdout.tty?
      end

      option ["-l", "--[no-]log"],
             :flag, "log to file in addition to terminal (or not)\n",
             default: true


      subcommand "new", "Sets up a new atmos project",
                 Commands::New
      subcommand "generate", "Generate recipes for the repository",
                 Commands::Generate
      subcommand "bootstrap", "Init cloud provider for use with atmos",
                 Commands::Bootstrap
      subcommand "init", "Run terraform init",
                 Commands::Init
      subcommand "plan", "Run terraform plan",
                 Commands::Plan
      subcommand "apply", "Run terraform apply",
                 Commands::Apply
      subcommand "destroy", "Run terraform destroy",
                 Commands::Destroy
      subcommand "terraform", "Run all other terraform commands",
                 Commands::Terraform
      subcommand "account", "Account management commands",
                 Commands::Account
      subcommand "user", "User management commands",
                 Commands::User
      subcommand "otp", "Otp tools",
                 Commands::Otp
      subcommand "secret", "Secret management commands",
                 Commands::Secret
      subcommand "auth_exec", "Authenticated exec",
                 Commands::AuthExec
      subcommand "container", "Container tools",
                 Commands::Container

      subcommand "version", "Display version" do
        def execute
          logger.info "Atmos Version #{VERSION}"
        end
      end

      subcommand "config", "Display expanded config for atmos_env" do
        def execute
          logger.info YAML.dump(Atmos.config.to_h)
        end
      end

      # hook into clamp lifecycle to force logging setup even when we are calling
      # a subcommand
      def parse(arguments)
        super
        if Atmos.config.nil?
          Atmos.config = Config.new(atmos_env, atmos_group)
          log = Atmos.config.is_atmos_repo? && log? ? "atmos.log" : nil
          Logging.setup_logging(debug?, color?, log)
          UI.color_enabled = color?

          Atmos.config.add_user_load_path(*load_path_list)
          Atmos.config.plugin_manager.load_plugins
        end
      end

    end

  end
end
