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
            current_level[p] = current_level[p] | Array(value)
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

    def self.add_config(yml_file, key, value, additive: true)
      orig_config_with_comments = File.read(yml_file)

      comment_places = {}
      comment_lines = []
      orig_config_with_comments.each_line do |line|
        line.gsub!(/\s+$/, "\n")
        if line =~ /^\s*(#.*)?$/
          comment_lines << line
        else
          if comment_lines.present?
            comment_places[line.chomp] = comment_lines
            comment_lines = []
          end
        end
      end
      comment_places["<EOF>"] = comment_lines

      orig_config = SettingsHash.new((YAML.load_file(yml_file) rescue {}))
      orig_config.notation_put(key, value, additive: additive)
      new_config_no_comments = YAML.dump(orig_config.to_hash)
      new_config_no_comments.sub!(/\A---\n/, "")

      new_yml = ""
      new_config_no_comments.each_line do |line|
        line.gsub!(/\s+$/, "\n")
        cline = comment_places.keys.find {|k| line =~ /^#{k}/ }
        comments = comment_places[cline]
        comments.each {|comment| new_yml << comment } if comments
        new_yml << line
      end
      comment_places["<EOF>"].each {|comment| new_yml << comment }

      return new_yml
    end

  end
end
