require 'clamp'
# require 'active_support/core_ext/string'
require 'sigdump/setup'
require 'atmos'
require 'atmos/logging'
require 'atmos/commands/init'
require 'atmos/commands/generate'

module Atmos

  # The command line interface to atmos
  class CLI < Clamp::Command

    include GemLogger::LoggerSupport

    def self.description
      desc = <<-DESC
        Atmos version #{Atmos::VERSION}

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
           :flag, "colorize output (or not)\n"

    def default_color?
       ! logfile.present?
    end

    option ["-l", "--logfile"],
           "FILE", "log to given file\n"


    subcommand "init", "Initialize the repository", Atmos::Commands::Init
    subcommand "generate", "Generate recipes for the repository", Atmos::Commands::Generate

    subcommand "version", "Display version" do
      def execute
        logger.info "Atmos Version #{Atmos::VERSION}"
        # logger.debug "Debug Atmos!"
        # logger.info "Info Atmos!"
        # logger.warn "Warn Atmos!"
        # logger.error "Error Atmos!"
      end
    end

    # hook into clamp lifecycle to force logging setup even when we are calling
    # a subcommand
    def parse(arguments)
      super
      Atmos::Logging.setup_logging(debug?, color?, logfile)
    end

  end

end
