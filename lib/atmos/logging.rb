require 'gem_logger'
require 'logging'
require 'active_support/concern'

Logging.format_as :inspect
Logging.backtrace true

Logging.color_scheme(
    'bright',
    lines: {
        debug: :green,
        info: :default,
        warn: :yellow,
        error: :red,
        fatal: [:white, :on_red]
    },
    date: :blue,
    logger: :cyan,
    message: :magenta
)

Logging.logger.root.level = :info

module Atmos

  module LoggingConcern
    extend ActiveSupport::Concern

    def logger
      ::Logging.logger[self.class]
    end

    module ClassMethods
      def logger
        ::Logging.logger[self]
      end
    end

  end

  module Logging

    extend ActiveSupport::Concern

    attr_accessor :testing

    def sio
      ::Logging.logger.root.appenders.first {|a| a.name == 'sio'}
    end

    def contents
      sio.sio.to_s
    end

    def clear
      sio.clear
    end

    def setup_logging(debug, color, logfile)
      ::Logging.logger.root.level = :debug if debug
      pattern_options = {}

      if color
        pattern_options[:color_scheme] = 'bright'
      end

      if debug || logfile.present?
        pattern_options[:pattern] = '[%d] %-5l %c{2} %m\n'
      else
        pattern_options[:pattern] = '%m\n'
      end


      if logfile.present?

        appender = ::Logging.appenders.file(
            logfile,
            layout: ::Logging.layouts.pattern(pattern_options)
        )

        # hack to assign stdout/err to logfile if logging to file
        io = appender.instance_variable_get(:@io)
        $stdout = $stderr = io

      else

        if self.testing

          appender = ::Logging.appenders.string_io(
              'sio',
              layout: ::Logging.layouts.pattern(pattern_options)
          )

        else

          appender = ::Logging.appenders.stdout(
              'stdout',
              layout: ::Logging.layouts.pattern(pattern_options)
          )

        end

      end

      ::Logging.logger.root.appenders = appender

    end

    extend self
    end

end

GemLogger.default_logger = Logging.logger.root
GemLogger.logger_concern = Atmos::LoggingConcern
