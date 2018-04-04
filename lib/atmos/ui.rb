require_relative '../atmos'
require 'highline'
require 'rainbow'
require 'yaml'
require 'open3'
require 'os'
require 'hashie'

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

      def agree(question, character=nil, &details)
        s = @color ? Rainbow(question).send(@color) : question
        @atmos_ui.agree(question, character, &details)
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

    def ask(question, answer_type=nil, &details)
      return Markup.new().ask(question, answer_type, &details)
    end

    def agree(question, character=nil, &details)
      return Markup.new().agree(question, character, &details)
    end

    # Pretty display of hashes
    def display(data)
      data = Hashie.stringify_keys(data)
      display = YAML.dump(data).sub(/\A---\n/, "").gsub(/^/, "  ")
    end

    def notify(message:nil, title: nil, modal: false, **opts)

      result = {
          'stdout' => '',
          'success' => ''
      }

      message = message.to_s
      title = title.present? ? title.to_s : "Atmos Notification"
      modal = ["true", "1"].include?(modal.to_s)
      modal = false if Atmos.config["ui.notify.disable_modal"]

      return result if Atmos.config["ui.notify.disable"].to_s == "true"

      command = Atmos.config["ui.notify.command"]

      if command.present?

        raise ArgumentError.new("notify command must be a list") if ! command.is_a?(Array)

        command = command.collect do |c|
          c = c.gsub("{{title}}", title)
          c = c.gsub("{{message}}", message)
          c = c.gsub("{{modal}}", modal.to_s)
        end
        result.merge! run_ui_process(*command)

      elsif OS.mac?
        display_method = modal ? "displayDialog" : "displayNotification"

        dialogScript = <<~EOF
          var app = Application.currentApplication();
          app.includeStandardAdditions = true;
          app.#{display_method}(
            #{JSON.generate(message)}, {
              withTitle: #{JSON.generate(title)},
              buttons: ['OK'],
              defaultButton: 1
          })
        EOF

        result.merge! run_ui_process("osascript", "-l", "JavaScript", "-e", dialogScript)

      elsif OS.linux?
        # TODO: add a modal option
        result.merge! run_ui_process("notify-send", title, message)

      # TODO windows notifications?
      # elseif OS.windows?

      else
        logger.debug("Notifications are unsupported on this OS")
        logger.info("\n#{title}: #{message}\n")
      end

      return result
    end

    private

    def run_ui_process(*args)
      stdout, status = Open3.capture2e(*args)
      result = {'stdout' => stdout, 'success' => status.success?.to_s}
      if ! status.success?
        result['error'] = "Notification process failed"
        logger.debug("Failed to run notification utility: #{stdout}")
      end
      return result
    end

  end
end
