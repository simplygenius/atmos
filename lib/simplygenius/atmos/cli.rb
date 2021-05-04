require_relative '../atmos'
require_relative '../atmos/ui'
require 'clamp'
require 'sigdump/setup'
require 'open-uri'

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
             :flag, "debug output",
             default: false

      option ["-q", "--quiet"],
             :flag, "suppress output",
             default: false

      option ["-c", "--[no-]color"],
             :flag, "colorize output (or not) (default: $stdout.tty?)"

      option ["-e", "--atmos-env"],
             'ENV', "The atmos environment",
             environment_variable: 'ATMOS_ENV', default: 'ops'

      option ["-g", "--atmos-group"],
             'GROUP', "The atmos working group for selecting recipe groups",
             default: 'default'

      option ["-p", "--load-path"],
             "PATH", "adds additional paths to ruby load path",
             multivalued: true

      option ["-o", "--override"],
             "KEYVALUE", "overrides atmos configuration in the form 'some.config=value' where value can be expressed in yaml form for complex types e.g. foo=1 foo=abc, foo=[x, y], foo={x: y}",
             multivalued: true

      option ["-v", "--version"],
             :flag, "Shows the atmos version"

      def default_color?
         $stdout.tty?
      end

      option ["-l", "--[no-]log"],
             :flag, "log to file in addition to terminal (or not)",
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
      subcommand "tfutil", "Terraform tools",
                 Commands::TfUtil

      subcommand "version", "Display version" do
        def execute
          logger.info "Atmos Version #{VERSION}"
        end
      end

      subcommand "config", "Display expanded config for atmos_env" do

        option ["-j", "--json"],
               :flag, "Dump config as json instead of yaml"

        parameter "PATH",
                  "The dot notation path of a specific config item to get",
                  required: false

        def execute
          if path
            result = Atmos.config[path]
            result = case result
              when Hash
                result.to_h
              when Array
                result.to_a
              else
                result
            end
          else
            result = Atmos.config.to_h
          end

          if json?
            output = JSON.pretty_generate(result)
          else
            output = YAML.dump(result).sub(/^\s*---\s*/, '')
          end
          logger.info output
        end
      end

      def fetch_latest_version
        begin
          latest_ver = JSON.parse(URI.open("https://rubygems.org/api/v1/versions/simplygenius-atmos/latest.json").read)['version']
        rescue => e
          latest_ver = "[Version Fetch Failed]"
          logger.log_exception(e, "Couldn't check latest atmos gem version", level: :debug)
        end
        latest_ver
      end

      def version_check(atmos_version)

        required_ver = Atmos.config["atmos.version_requirement"]
        if required_ver.present?
          case required_ver

          when "latest"
            latest_ver = fetch_latest_version

            if latest_ver != atmos_version
              raise "The atmos version (#{atmos_version}) does not match the given requirement (latest: #{latest_ver})"
            end

          when /[~<>=]*\s*[\d\.]*/
            if ! Gem::Dependency.new('', required_ver).match?('', atmos_version)
              raise "The atmos version (#{atmos_version}) does not match the given requirement (#{required_ver})"
            end

          else
            raise "Invalid atmos.version_requirement, should be 'latest' or in a gem dependency form"
          end
        end

      end

      # hook into clamp lifecycle to force logging setup even when we are calling
      # a subcommand
      def parse(arguments)
        super
        if Atmos.config.nil?
          Atmos.config = Config.new(atmos_env, atmos_group)
          log = Atmos.config.is_atmos_repo? && log? ? "atmos.log" : nil
          level = :info
          level = :debug if debug?
          level = :error if quiet?

          Logging.setup_logging(level, color?, log)

          override_list.each do |o|
            k, v = o.split("=")
            v = YAML.load(v)
            logger.debug("Overriding config '#{k}' = #{v.inspect}")
            Atmos.config.[]=(k, v, additive: false)
          end

          UI.color_enabled = color?

          Atmos.config.add_user_load_path(*load_path_list)
          Atmos.config.plugin_manager.load_plugins

          # So we can show just the version with the -v flag
          if version?
            logger.info "Atmos Version #{VERSION}"
            exit(0)
          end

          version_check(VERSION)
        end
      end

      # Hook into clamp lifecycle to globally handle errors
      class << self
        def run(invocation_path = File.basename($PROGRAM_NAME), arguments = ARGV, context = {})
          begin
            super
          rescue SystemExit => e
            if ! e.success?
              logger.log_exception(e, "Failure exit", level: :debug)
              logger.error(e.message)
              raise
            end
          rescue Exception => e
            logger.log_exception(e, "Unhandled exception", level: :debug)
            logger.error(e.message)
            exit!
          end
        end
      end

    end

  end
end

# Hack to make clamp usage less of a pain to get long lines to fit within a
# standard terminal width
class Clamp::Help::Builder

  def word_wrap(text, line_width:)
    text.split("\n").collect do |line|
      line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip.split("\n") : line
    end.flatten
  end

  def string
    line_width = 79
    indent_size = 4
    indent = " " * indent_size
    StringIO.new.tap do |out|
      lines.each do |line|
        case line
        when Array
          out << indent
          out.puts(line[0])
          formatted_line = line[1].gsub(/\((default|required)/, "\n\\0")
          word_wrap(formatted_line, line_width: (line_width - indent_size * 2)).each do |l|
            out << (indent * 2)
            out.puts(l)
          end
        else
          out.puts(line)
        end
      end
    end.string
  end

end
