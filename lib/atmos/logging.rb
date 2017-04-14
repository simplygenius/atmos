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
      Logging.logger[self.class]
    end

    module ClassMethods
      def logger
        Logging.logger[self]
      end
    end

  end
end

GemLogger.default_logger = Logging.logger.root
GemLogger.logger_concern = Atmos::LoggingConcern
