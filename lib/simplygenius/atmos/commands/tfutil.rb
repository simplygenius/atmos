require_relative 'base_command'
require 'json'
require 'open3'
require 'clipboard'

module SimplyGenius
  module Atmos
    module Commands

      class TfUtil < BaseCommand

        def self.description
          "Useful utilities when calling out from terraform with data.external"
        end

        subcommand "jsonify", "Manages json on stdin/out to conform to use in terraform data.external" do

          banner "Ensures json output only contains a single level Hash with string values (e.g. when execing curl returns a deep json hash of mixed values)"

          option ["-a", "--atmos_config"],
                 :flag, "Includes the atmos config in the hash from parsing json on stdin"

          option ["-c", "--clipboard"],
                 :flag, "Copies the actual command used to the clipboard to allow external debugging"

          option ["-j", "--json"],
                 :flag, "The command output is parsed as json"

          option ["-x", "--[no-]exit"],
                 :flag, "Exit with the command's exit code on failure (or not)", default: true

          parameter "COMMAND ...",
                    "The command to call", :attribute_name => :command

          # Recursively converts all values to strings as required by terraform data.external
          def stringify(obj)
            case obj
            when Hash
              Hash[obj.collect {|k, v| [k, stringify(v)] }]
            when Array
              obj.collect {|v| stringify(v) }
            else
              obj.to_s
            end
          end

          # Makes a hash have only a single level as required by terraform data.external
          def flatten(obj)
            result = {}

            if obj.is_a? Hash
              obj.each do |k, v|
                ev = case v
                     when String
                       v
                     when Hash, Array
                       JSON.generate(v)
                     else
                       v.to_s
                     end
                result[k] = ev
              end
            else
              result["data"] = JSON.generate(obj)
            end

            return result
          end

          def maybe_read_stdin
            data = nil
            begin
              chunk = $stdin.read_nonblock(1)
              data = chunk + $stdin.read
              logger.debug("Received stdin: " + data)
            rescue EOFError, SystemCallError => e # All Errno exceptions
              data = nil
              logger.debug("No stdin due to: #{e}")
            end
            return data
          end

          def execute
            params = JSON.parse(maybe_read_stdin || '{}')
            params = SettingsHash.new(params)
            params.enable_expansion = true
            if atmos_config?
              params = Atmos.config.config_merge(SettingsHash.new(Atmos.config.to_h), params)
            end
            expanded_command = command.collect {|c| params.expand_string(c) }

            begin
              formatted_command = expanded_command.collect {|a| "'#{a}'" }.join(" ")
              logger.debug("Running command: #{formatted_command}")
              Clipboard.copy(formatted_command) if clipboard?

              cmd_opts = {}
              cmd_opts[:stdin_data] = params[:stdin] if params.key?(:stdin)
              stdout, stderr, status = Open3.capture3(*expanded_command, **cmd_opts)
              result = {stdout: stdout, stderr: stderr, exitcode: status.exitstatus.to_s}
              logger.debug("Command result: #{result.inspect}")

              if exit? && status.exitstatus != 0
                $stderr.puts stdout
                $stderr.puts stderr
                exit status.exitstatus
              end

              if json?
                result = result.merge(flatten(stringify(JSON.parse(stdout))))
              end

              logger.debug("Json output: #{result.inspect}")
              $stdout.puts JSON.generate(result)

            rescue => e
              $stderr.puts("#{e.class}: #{e.message}")
              exit 1
            end

          end

        end

      end

    end
  end
end
