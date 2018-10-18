require_relative '../atmos'
require_relative '../atmos/settings_hash'
require_relative '../atmos/provider_factory'
require_relative '../atmos/plugin_manager'
require 'yaml'
require 'fileutils'
require 'find'

module SimplyGenius
  module Atmos

    class Config
      include GemLogger::LoggerSupport
      include FileUtils

      attr_accessor :atmos_env, :working_group,
                    :root_dir,
                    :config_file,
                    :tmp_root

      def initialize(atmos_env, working_group = 'default')
        @atmos_env = atmos_env
        @working_group = working_group
        @root_dir = File.expand_path(Dir.pwd)
        @config_file = File.join(root_dir, "config", "atmos.yml")
        @tmp_root = File.join(root_dir, "tmp")
        @included_configs = []
      end

      def is_atmos_repo?
        File.exist?(config_file)
      end

      def [](key)
        load
        result = @config.notation_get(key)
        return result
      end

      def to_h
        load
        @config.to_hash
      end

      def provider
        @provider ||= ProviderFactory.get(self[:provider])
      end

      def plugin_manager
        @plugin_manager ||= PluginManager.new(self["atmos.plugins"])
      end

      def all_env_names
        load
        @full_config[:environments].keys
      end

      def account_hash
        load
        environments = @full_config[:environments] || {}
        environments.inject(Hash.new) do |accum, entry|
          accum[entry.first] = entry.last[:account_id]
          accum
        end
      end

      def tmp_dir
        @tmp_dir ||= begin
          dir = File.join(tmp_root, atmos_env)
          logger.debug("Tmp dir: #{dir}")
          mkdir_p(dir)
          dir
        end
      end

      def auth_cache_dir
        @auth_cache_dir ||= begin
          dir = File.join(tmp_dir, 'auth')
          logger.debug("Auth cache dir: #{dir}")
          mkdir_p(dir)
          dir
        end
      end

      def tf_working_dir
        @tf_working_dir ||= begin
          dir = File.join(tmp_dir, 'tf', working_group)
          logger.debug("Terraform working dir: #{dir}")
          mkdir_p(dir)
          dir
        end
      end

      def add_user_load_path(*paths)
        load_path = paths + Array(self["atmos.load_path"])
        if load_path.present?
          load_path = load_path.collect { |path| File.expand_path(path) }
          logger.debug("Adding to load path: #{load_path.inspect}")
          $LOAD_PATH.insert(0, *load_path)
        end
      end

      private

      INTERP_PATTERN = /(\#\{([^\}]+)\})/

      def config_merge(lhs, rhs)
        result = nil

        return rhs if lhs.nil?
        return lhs if rhs.nil?

        # Warn if user fat fingered config
        unless lhs.is_a?(rhs.class) || rhs.is_a?(lhs.class)
          logger.warn("Different types in deep merge: #{lhs.class}, #{rhs.class}")
        end

        case rhs
        when Hash
          result = lhs.deep_dup

          lhs.each do |k, v|
            if k =~ /^\^(.*)/
              key = k.is_a?(Symbol) ? $1.to_sym : $1
              result[key] = result.delete(k)
            end
          end

          rhs.each do |k, v|
            if k =~ /^\^(.*)/
              key = k.is_a?(Symbol) ? $1.to_sym : $1
              result[key] = v
            else
              result[k] = config_merge(result[k], v)
            end
          end
        when Enumerable
          result = lhs + rhs
        else
          result = rhs
        end

        return result
      end

      def load_config_sources(relative_root, config, *patterns)
        patterns.each do |pattern|
          logger.debug("Loading atmos config files using pattern: #{pattern}")

          # relative to main atmos config file unless qualified
          if pattern !~ /^[\/~]/
            pattern = File.join(relative_root, pattern)
          end
          # expand to handle tilde/etc
          pattern = File.expand_path(pattern)
          logger.debug("Expanded pattern: #{pattern}")

          Dir[pattern].each do |f|
            logger.debug("Loading atmos config file: #{f}")
            data = YAML.load_file(f)
            if data == false
              logger.debug("Skipping empty config file: #{f}")
            else
              h = SettingsHash.new(data)
              config = config_merge(config, h)
              @included_configs << f
            end
          end
        end

        config
      end

      def load_submap(relative_root, group, name, config)
        submap_dir = File.join(relative_root, 'atmos', group)
        submap_file = File.join(submap_dir, "#{name}.yml")
        if File.exist?(submap_file)
          logger.debug("Loading atmos #{group} config file: #{submap_file}")
          data  = YAML.load_file(submap_file)
          if data == false
            logger.debug("Skipping empty config file: #{submap_file}")
          else
            h = SettingsHash.new({group => {name => data}})
            config = config_merge(config, h)
            @included_configs << submap_file
          end
        end

        begin
          submap = config.deep_fetch(group, name)
          config = config_merge(config, submap)
        rescue
          logger.debug("No #{group} config found for '#{name}'")
        end

        config
      end

      def load
        @config ||= begin

          logger.debug("Atmos env: #{atmos_env}")

          if ! File.exist?(config_file)
            logger.warn "Could not find an atmos config file at: #{config_file}"
            @full_config = SettingsHash.new
          else
            logger.debug("Loading atmos config file #{config_file}")
            @full_config = SettingsHash.new(YAML.load_file(config_file))
            @included_configs << config_file
          end

          @full_config = load_config_sources(File.dirname(config_file), @full_config, *Array(@full_config.notation_get("atmos.config_sources")))

          @full_config['provider'] = provider_name = @full_config['provider'] || 'aws'

          @full_config = load_submap(File.dirname(config_file), 'providers', provider_name, @full_config)
          @full_config = load_submap(File.dirname(config_file), 'environments', atmos_env, @full_config)

          global = SettingsHash.new(@full_config.reject {|k, v| ['providers', 'environments'].include?(k) })
          conf = config_merge(global, {
              atmos_env: atmos_env,
              atmos_working_group: working_group,
              atmos_version: VERSION
          })
          expand(conf, conf)
        end
      end

      def expand(config, obj)
        case obj
          when Hash
            SettingsHash.new(Hash[obj.collect {|k, v| [k, expand(config, v)] }])
          when Array
            result = obj.collect {|i| expand(config, i) }
            # HACK: accounting for the case when someone wants to force an override using '^' as the first list item, when
            # there is no upstream to override (i.e. merge proc doesn't get triggered as key is unique, so just added verbatim)
            result.delete_at(0) if result[0] == "^"
            result
          when String
            result = obj
            result.scan(INTERP_PATTERN).each do |substr, statement|
              # TODO: check for cycles
              if statement =~ /^[\w\.\[\]]$/
                val = config.notation_get(statement)
              else
                # TODO: be consistent with dot notation between eval and
                # notation_get.  eval ends up calling Hashie method_missing,
                # which returns nil if a key doesn't exist, causing a nil
                # exception for next item in chain, while notation_get returns
                # nil gracefully for the entire chain (preferred)
                begin
                  val = eval(statement, config.instance_eval("binding"))
                rescue => e
                  file, line = find_config_error(substr)
                  file_msg = file.nil? ? "" : " in #{File.basename(file)}:#{line}"
                  raise RuntimeError.new("Failing config statement '#{substr}'#{file_msg} => #{e.class} #{e.message}")
                end
              end
              result = result.sub(substr, expand(config, val).to_s)
            end
            result = true if result == 'true'
            result = false if result == 'false'
            result
          else
            obj
        end
      end

      def find_config_error(statement)
        filename = nil
        line = 0

        @included_configs.each do |c|
          current_line = 0
          File.foreach(c) do |f|
            current_line += 1
            if f.include?(statement)
              filename = c
              line = current_line
              break
            end
          end
        end

        return filename, line
      end

    end

  end
end
