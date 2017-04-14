require 'clamp'
require 'yaml'
require 'active_support/core_ext/string'
require 'sigdump/setup'
require 'atmos'

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

    option ["-v", "--version"],
           :flag, "print version and exit\n",
           default: false

    option ["-l", "--logfile"],
           "FILE", "log to given file\n"

    def execute

      if version?
        puts "Atmos Version #{Atmos::VERSION}"
        return
      end

      setup_logging

      logger.debug "Debug Atmos!"
      logger.info "Info Atmos!"
      logger.warn "Warn Atmos!"
      logger.error "Error Atmos!"

    end

    private

    def setup_logging
      Logging.logger.root.level = :debug if debug?
      pattern_options = {}

      if color?
        pattern_options[:color_scheme] = 'bright'
      end

      if debug? || logfile.present?
        pattern_options[:pattern] = '[%d] %-5l %c{2} %m\n'
      else
        pattern_options[:pattern] = '%m\n'
      end


      if logfile.present?

        appender = Logging.appenders.file(
            logfile,
            layout: Logging.layouts.pattern(pattern_options)
        )

        # hack to assign stdout/err to logfile if logging to file
        io = appender.instance_variable_get(:@io)
        $stdout = $stderr = io

      else

        appender = Logging.appenders.stdout(
            'stdout',
            layout: Logging.layouts.pattern(pattern_options)
        )

      end

      Logging.logger.root.appenders = appender

    end

  end

end
