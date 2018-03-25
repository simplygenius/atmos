require 'atmos'
require 'highline'
require 'rainbow'
require 'yaml'

module Atmos
  module UI
    extend ActiveSupport::Concern
    include GemLogger::LoggerSupport

    def self.color_enabled=(val)
      Rainbow.enabled = val
    end

    def self.color_enabled
      Rainbow.enabled
    end

    class Markup
      def initialize(color = nil)
        @color = color
        @atmos_ui = HighLine.new
      end

      def say(statement)
        statement = @color ? Rainbow(statement).send(@color) : statement
        @atmos_ui.say(statement)
      end

      def ask(question, answer_type=nil, &details)
        s = @color ? Rainbow(question).send(@color) : question
        @atmos_ui.ask(question, answer_type, &details)
      end
    end

    def warn
      return Markup.new(:yellow)
    end

    def error
      return Markup.new(:red)
    end

    def say(statement)
      return Markup.new().say(statement)
    end

    # Pretty display of hashes
    def display(data)
      display = YAML.dump(data).sub(/\A---\n/, "")
    end

    def ask(question, answer_type=nil, &details)
      return Markup.new().ask(question, answer_type, &details)
    end
  end
end
