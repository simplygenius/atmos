require_relative '../../atmos'
require_relative 'output_filter'
require 'deepsort'
require 'diffy'
require 'json'
require 'yaml'

module SimplyGenius
  module Atmos
    module Plugins

      class JsonDiff < SimplyGenius::Atmos::Plugins::OutputFilter

        def initialize(context)
          super
          @plan_detected = false
          @json_data = ""
        end

        def filter(data, flushing: false)

          # If we are flushing and never saw a json end, then flush the data we have buffered
          if flushing && @saving_json
            buffer = @json_data + data
            @json_data = ""
            return buffer
          end

          # TODO: roll up plan detection so we don't have many plugins doing the same regexp match
          if data =~ /^[\e\[\dm\s]*Terraform will perform the following actions:[\e\[\dm\s]*$/
            @plan_detected = true
          end

          if @plan_detected

            if data =~ /^.*:\s*"[\[\{]/
              @saving_json = true
            end

            if @saving_json
              @json_data << data

              if data =~ /[\]\}][\s\\n]*[^\\]"[^"]*$/
                @saving_json = false
                with_diff = @json_data.sub(/^(.*:\s*)"([\[\{].*[\]\}])[\s\\n]*"\s*=>\s*"([\[\{].*[\]\}])[\s\\n]*"(.*)$/) do |m|
                  begin
                    "#{$1}\n#{jsondiff($2, $3)}\n#{$4}"
                  rescue JSON::ParserError => e
                    logger.warn("Failed to parse JSON for diff: #{e.message}")
                    "#{$1}\n\n#{$2}\n\n=>\n\n#{$3}\n\n#{$4}"
                  end
                end
                @json_data = ""
                return with_diff
              end

              return ""
            end

          end

          data
        end

        def unescape(s)
          YAML.load(%Q(---\n"#{s}"\n))
        end

        def jsondiff(lhs, rhs)
          lhs = unescape(lhs)
          rhs = unescape(rhs)

          jl = JSON.parse(lhs).deep_sort
          jr = JSON.parse(rhs).deep_sort

          sl = JSON.pretty_generate(jl)
          sr = JSON.pretty_generate(jr)

          if sl == sr
            result = "No differences"
          else
            result = Diffy::Diff.new("#{sl}\n", "#{sr}\n").to_s
          end

          result
        end


      end

    end
  end
end


