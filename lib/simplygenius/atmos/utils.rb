require_relative '../atmos'

module SimplyGenius
  module Atmos

    module Utils

      extend ActiveSupport::Concern
      include GemLogger::LoggerSupport

      class SymbolizedMash < ::Hashie::Mash
        include Hashie::Extensions::Mash::SymbolizeKeys
      end

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

      # wraps to an 80 character limit by adding newlines
      def wrap(str)
        result = ""
        count = 0
        str.each do |c|
          result << c
          if count >= 78
            result << "\n"
            count = 0
          else
            count += 1
          end
        end
        return result
      end

      extend self

    end

  end
end
