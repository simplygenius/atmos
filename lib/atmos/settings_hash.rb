require 'hashie'

module Atmos

  class SettingsHash <  Hashie::Mash
    include GemLogger::LoggerSupport
    include Hashie::Extensions::DeepMerge
    include Hashie::Extensions::DeepFetch
    disable_warnings

    PATH_PATTERN = /[\.\[\]]/

    def notation_get(key)
      path = key.to_s.split(PATH_PATTERN).compact
      path = path.collect {|p| p =~ /^\d+$/ ? p.to_i : p }
      result = nil

      begin
        result = deep_fetch(*path)
      rescue Hashie::Extensions::DeepFetch::UndefinedPathError => e
        logger.debug("Settings missing value for key='#{key}'")
      end

      return result
    end

    def notation_put(key, value, additive: true)
      path = key.to_s.split(PATH_PATTERN).compact
      path = path.collect {|p| p =~ /^\d+$/ ? p.to_i : p }
      current_level = self
      path.each_with_index do |p, i|

        if i == path.size - 1
          if additive && current_level[p].is_a?(Array)
            current_level[p].concat(Array(value))
          else
            current_level[p] = value
          end
        else
          if current_level[p].nil?
            if path[i+1].is_a?(Integer)
              current_level[p] = []
            else
              current_level[p] = {}
            end
          end
        end

        current_level = current_level[p]
      end
    end

  end
end
