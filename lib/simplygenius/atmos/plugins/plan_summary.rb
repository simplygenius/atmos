require_relative '../../atmos'
require_relative 'output_filter'

module SimplyGenius
  module Atmos
    module Plugins

      class PlanSummary < SimplyGenius::Atmos::Plugins::OutputFilter

        def initialize(context)
          super
          @plan_detected = false
          @summary_data = ""
        end

        def filter(data, flushing: false)
          summary_saved = false
          if data =~ /^[\e\[\dm\s]*Terraform will perform the following actions:[\e\[\dm\s]*$/
            @plan_detected = true
            @summary_data = data.sub(/.*Terraform will perform the following actions:[^\n]*\n/m, "")
            summary_saved = true
          end

          if @plan_detected
            @summary_data << data unless summary_saved
            data.sub!(/^[\e\[\dm\s]*Plan:.*$/) do |m|
              summary = summarize(@summary_data)
              m + "\n\n#{summary}\n"
            end
          end

          data
        end

        def summarize(data)
          # Looking for +/-/~ at start within 2 spaces, could also look for lines that end with {
          lines = data.lines.select { |l|
            l = l.gsub(/\e\[\d+m/, '')
            l =~ /^\s{0,2}[~+\-<]/
          }.collect(&:chomp)
          lines = lines.reject {|l| l =~ /-----/ }
          "Plan Summary:\n#{lines.join("\n")}"
        end

      end

    end
  end
end
