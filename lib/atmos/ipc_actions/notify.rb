require 'atmos'
require 'open3'
require 'os'

module Atmos
  module IpcActions
    class Notify
      include GemLogger::LoggerSupport

      def initialize()
      end

      def execute(message:nil, title: nil, modal: false, **opts)

        result = {
            'stdout' => '',
            'success' => ''
        }

        message = message.to_s
        title = title.present? ? title.to_s : "Atmos Notification"
        modal = ["true", "1"].include?(modal.to_s)
        modal = false if Atmos.config["ipc.notify.disable_modal"]

        return result if Atmos.config["ipc.notify.disable"].to_s == "true"

        command = Atmos.config["ipc.notify.command"]

        if command.present?

          raise ArgumentError.new("notify command must be a list") if ! command.is_a?(Array)

          command = command.collect do |c|
            c = c.gsub("{{title}}", title)
            c = c.gsub("{{message}}", message)
            c = c.gsub("{{modal}}", modal.to_s)
          end
          result.merge! run(*command)

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

          result.merge! run("osascript", "-l", "JavaScript", "-e", dialogScript)

        elsif OS.linux?
          # TODO: add a modal option
          result.merge! run("notify-send", title, message)

        # TODO windows notifications?
        # elseif OS.windows?

        else
          logger.debug("Notifications are unsupported on this OS")
          logger.info("\n#{title}: #{message}\n")
        end

        return result
      end

      private

      def run(*args)
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
end
