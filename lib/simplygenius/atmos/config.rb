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
                    :user_config_file,
                    :tmp_root

      def initialize(atmos_env, working_group = 'default')
        @atmos_env = atmos_env
        @working_group = working_group
        @root_dir = File.expand_path(Dir.pwd)
        @config_file = File.join(root_dir, "config", "atmos.yml")
        @user_config_file = "~/.atmos.yml"
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

      def []=(key, value)
        load
        result = @config.notation_put(key, value)
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
        (@full_config[:environments] || {}).keys
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

      def save_user_config_file(data, merge_to_existing: true)
        logger.debug("Saving to user config file (merging=#{merge_to_existing}): #{user_config_file}")

        if merge_to_existing
          existing = load_file(user_config_file, SettingsHash.new)
          data = config_merge(existing, data, ["saving #{user_config_file}"])
        end
        File.write(user_config_file, YAML.dump(data.to_hash))
        File.chmod(0600, user_config_file)
      end

      def config_merge(lhs, rhs, debug_state=[])
        result = nil

        return rhs if lhs.nil?
        return lhs if rhs.nil?

        # Warn if user fat fingered config
        if lhs.is_a?(rhs.class) || rhs.is_a?(lhs.class)

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
                result[k] = config_merge(result[k], v, debug_state + [k])
              end
            end
          when Enumerable
            result = lhs + rhs
          else
            result = rhs
          end

        else

          logger.warn("Type mismatch while merging in: #{debug_state.delete_at(0)}")
          logger.warn("Deep merge path: #{debug_state.join(" -> ")}")
          logger.warn("Deep merge LHS (#{lhs.class}): #{lhs.inspect}")
          logger.warn("Deep merge RHS (#{rhs.class}): #{rhs.inspect}")
          result = rhs

        end

        return result
      end

      private

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
            config = load_file(f, config)
          end
        end

        config
      end

      def load_submap(relative_root, group, name, config)
        submap_dir = File.join(relative_root, 'atmos', group)
        submap_file = File.join(submap_dir, "#{name}.yml")
        config = load_file(submap_file, config) do |d|
          SettingsHash.new({group => {name => d}})
        end

        begin
          submap = config.deep_fetch(group, name)
          config = config_merge(config, submap, ["#{submap_file} submap(#{group}.#{name})"])
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
            @full_config = load_file(config_file, SettingsHash.new)
          end

          @full_config = load_config_sources(File.dirname(config_file), @full_config, *Array(@full_config.notation_get("atmos.config_sources")))

          @full_config['provider'] = provider_name = @full_config['provider'] || 'aws'

          @full_config = load_submap(File.dirname(config_file), 'providers', provider_name, @full_config)
          @full_config = load_submap(File.dirname(config_file), 'environments', atmos_env, @full_config)

          @user_config_file = @full_config.notation_get("atmos.user_config") || @user_config_file
          @user_config_file = File.expand_path(@user_config_file)
          @full_config = load_file(user_config_file, @full_config)

          global = SettingsHash.new(@full_config.reject {|k, v| ['providers', 'environments'].include?(k) })
          conf = config_merge(global, {
              atmos_env: atmos_env,
              atmos_working_group: working_group,
              atmos_version: VERSION
          }, ["builtins"])

          conf.error_resolver = ->(statement) { find_config_error(statement) }
          conf.enable_expansion = true
          conf

        end
      end

      def load_file(file, config=SettingsHash.new, &block)
        if File.exist?(file)
          logger.debug("Loading atmos config file #{file}")
          data = YAML.load_file(file)
          if ! data.is_a?(Hash)
            logger.debug("Skipping invalid atmos config file (not hash-like): #{file}")
          else
            data = SettingsHash.new(data)
            data = block.call(data) if block
            config = config_merge(config, data, [file])
            @included_configs << file
          end
        else
          logger.debug   "Could not find an atmos config file at: #{file}"
        end

        config
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
