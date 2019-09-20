require 'logging'
require 'gem_logger'
require 'rainbow'
require 'delegate'

module SimplyGenius
  module Atmos

    module Logging

      module GemLoggerConcern
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

      class CaptureStream < SimpleDelegator

        def initialize(logger_name, appender, stream, color=nil)
          super(stream)
          @color = stream.tty? && color ? color : nil
          @logger = ::Logging.logger[logger_name]
          @logger.appenders = [appender]
          @logger.additive = false
        end

        def strip_color(str)
          str.gsub(/\e\[\d+m/, '')
        end

        def write(data)
          @logger.info(strip_color(data))
          if @color
            count = 0
            d = data.lines.each do |l|
              cl = Kernel.send(:Rainbow, l).send(@color)
              count += super(cl)
            end
            return count
          else
            return super(data)
          end
        end
      end

      def self.init_logger
        return if @initialized
        @initialized = true

        ::Logging.format_as :inspect
        ::Logging.backtrace true

        ::Logging.color_scheme(
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

        ::Logging.logger.root.level = :info
        GemLogger.configure do |config|
          config.default_logger = ::Logging.logger.root
          config.logger_concern = Logging::GemLoggerConcern
        end
      end


      def self.testing
        @t
      end

      def self.testing=(t)
        @t = t
      end

      def self.sio
        ::Logging.logger.root.appenders.find {|a| a.name == 'sio' }
      end

      def self.contents
        sio.try(:sio).try(:to_s)
      end

      def self.clear
        sio.try(:clear)
      end

      def self.setup_logging(level, color, logfile)
        init_logger

        ::Logging.logger.root.level = level
        appenders = []
        detail_pattern = '[%d] %-5l %c{2} %m\n'
        plain_pattern = '%m\n'

        pattern_options = {
            pattern: plain_pattern
        }
        if color
          pattern_options[:color_scheme] = 'bright'
        end

        if self.testing

          appender = ::Logging.appenders.string_io(
              'sio',
              layout: ::Logging.layouts.pattern(pattern_options)
          )
          appenders << appender

        else

          appender = ::Logging.appenders.stdout(
              'stdout',
              layout: ::Logging.layouts.pattern(pattern_options)
          )
          appenders << appender

        end

        # Do this after setting up stdout appender so we don't duplicate output
        # to stdout with our capture
        if logfile.present?

          appender = ::Logging.appenders.file(
              logfile,
              truncate: true,
              layout: ::Logging.layouts.pattern(pattern: detail_pattern)
          )
          appenders << appender

          if ! $stdout.is_a? CaptureStream
            $stdout = CaptureStream.new("stdout", appender, $stdout)
            $stderr = CaptureStream.new("stderr", appender, $stderr, :red)
            silence_warnings {
              Object.const_set(:STDOUT, $stdout)
              Object.const_set(:STDERR, $stderr)
            }
          end

        end

        ::Logging.logger.root.appenders = appenders
      end

    end

  end
end
