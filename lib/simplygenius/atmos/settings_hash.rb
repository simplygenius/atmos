require 'hashie'
require_relative "../atmos/exceptions"

module SimplyGenius
  module Atmos

    class SettingsHash <  Hashie::Mash
      include GemLogger::LoggerSupport
      include Hashie::Extensions::DeepMerge
      include Hashie::Extensions::DeepFetch
      include SimplyGenius::Atmos::Exceptions
      disable_warnings

      PATH_PATTERN = /[\.\[\]]/
      INTERP_PATTERN = /(\#\{([^\}]+)\})/

      attr_accessor :_root_, :error_resolver, :enable_expansion

      alias orig_reader []

      def expand_results(name, &blk)
        # NOTE: we lookup locally first, then globally if a value is missing
        # locally.  To force a global lookup, use the explicit qualifier like
        # "_root_.path.to.config"

        value = blk.call(name)

        if value.nil? && _root_ && enable_expansion
          value = _root_[name]
        end

        if value.kind_of?(self.class) && value._root_.nil?
          value._root_ = _root_ || self
        end

        enable_expansion ? expand(value) : value
      end

      def expanding_reader(key)
        expand_results(key) {|k| orig_reader(k) }
      end

      def fetch(key, *args)
        expand_results(key) {|k| super(k, *args) }
      end

      def error_resolver
        @error_resolver || _root_.try(:error_resolver)
      end

      def enable_expansion
        @enable_expansion.nil? ? _root_.try(:enable_expansion) : @enable_expansion
      end

      alias [] expanding_reader

      # allows expansion when iterating
      def each
        each_key do |key|
          yield key, self[key]
        end
      end

      # allows expansion for to_a (which doesn't use each)
      def to_a
        self.collect {|k, v| [k, v]}
      end

      def format_error(msg, expr, ex=nil)
        file, line = nil, nil
        if error_resolver
          file, line = error_resolver.call(expr)
        end
        file_msg = file.nil? ? "" : " in #{File.basename(file)}:#{line}"
        msg = "#{msg} '#{expr}'#{file_msg}"
        if ex
          msg +=  " => #{ex.class} #{ex.message}"
        end
        return msg
      end

      def expand_string(obj)
        result = obj
        result.scan(INTERP_PATTERN).each do |substr, statement|
          # TODO: add an explicit check for cycles instead of relying on Stack error
          begin
            # TODO: be consistent with dot notation between eval and
            # notation_get.  eval ends up calling Hashie method_missing,
            # which returns nil if a key doesn't exist, causing a nil
            # exception for next item in chain, while notation_get returns
            # nil gracefully for the entire chain (preferred)
            val = eval(statement, binding, __FILE__)
          rescue SystemStackError => e
            raise ConfigInterpolationError.new(format_error("Cycle in interpolated config", substr))
          rescue StandardError => e
            raise ConfigInterpolationError.new(format_error("Failing config statement", substr, e))
          end
          result = result.sub(substr, val.to_s)
        end

        result = true if result == "true"
        result = false if result == "false"

        result
      end

      def expand(value)
        result = value
        case value
        when Hash
          value
        when String
          expand_string(value)
        when Enumerable
          value.map! {|v| expand(v)}
          # HACK: accounting for the case when someone wants to force an override using '^' as the first list item, when
          # there is no upstream to override (i.e. merge proc doesn't get triggered as key is unique, so just added verbatim)
          value.delete_at(0) if value[0] == "^"
          value
        else
          value
        end
      end

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
        # expansion disabled by default, but being explicit since we don't want
        # expansion when mutating config files from generators
        orig_config.enable_expansion = false
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
end
