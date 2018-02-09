require 'gem_logger'

module Atmos
  module Utils

    extend ActiveSupport::Concern
    include GemLogger::LoggerSupport

    # remove leading whitespace using first non-empty line to determine how
    # much space to remove from the rest. Skips empty lines
    def clean_indent(str)
      first = true
      first_size = 0
      str.lines.collect do |line|
        if line =~ /^(\s*)\S/ # line has at least one non-whitespace character
          if first
            first_size = Regexp.last_match(0).size
            first = false
          end
          line[(first_size - 1)..-1]
        else
          line
        end
      end.join()
    end

    extend self

  end
end
