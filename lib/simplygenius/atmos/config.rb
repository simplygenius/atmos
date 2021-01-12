require_relative '../atmos'
require_relative '../atmos/settings_hash'
require_relative '../atmos/provider_factory'
require_relative '../atmos/plugin_manager'
require 'yaml'
require 'fileutils'
require 'find'
require 'open-uri'

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

      def initialize(atmos_env, working_group = 'default', root: ENV['ATMOS_ROOT'], config: ENV['ATMOS_CONFIG'])
        @atmos_env = atmos_env
        @working_group = working_group
        @root_dir = File.expand_path(root || Dir.pwd)
        @config_file = config ? File.expand_path(config, root_dir) : File.join(root_dir, "config", "atmos.yml")
        @user_config_file = "~/.atmos.yml"
        @tmp_root = File.join(root_dir, "tmp")
        @included_configs = {}
      end

      def is_atmos_repo?
        File.exist?(config_file)
      end

      def [](key)
        load
        result = @config.notation_get(key)
        return result
      end

      def []=(key, value, additive: true)
        load
        result = @config.notation_put(key, value, additive: additive)
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
          data = finalize_merge(data)
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

            rhs.each do |k, v|
              new_state = debug_state + [k]

              # The load sequence could have multiple overrides and its not
              # obvious to the user which are lhs vs rhs, so rather than having
              # one seem to win arbitrarily, we collect them all additively
              # under their key, then at the end of the load process we push the
              # override back as a replacement for its base key in the
              # finalize_merge method. This means that if one has multiple
              # overrides for the same key (not usually what one wants), those
              # overrides get merged together additively before replacing the
              # base.  Thus the need for the log messages below.
              #
              if k =~ /^\^/
                logger.debug { "Override seen at #{new_state.join(" -> ")}" }
                logger.warn { "Multiple overrides on a single key seen at #{new_state.join(" -> ")}" } if result.has_key?(k)
              end

              result[k] = config_merge(result[k], v, new_state)
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

      def finalize_merge(config)
        result = config.deep_dup

        config.each do |k, v|

          key = k

          if k =~ /^\^(.*)/
            key = k.is_a?(Symbol) ? $1.to_sym : $1
            result[key] = result.delete(k)
          end

          if v.is_a?(Hash)
            result[key] = finalize_merge(v)
          end

        end

        return result
      end

      def load_remote_config_sources(config, *remote_sources)
        remote_sources.each do |remote_source|
          logger.debug("Loading remote atmos config file: #{remote_source}")
          contents = URI.open(remote_source).read
          config = load_config(remote_source, contents, config)
        end

        config
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

          Dir[pattern].sort.each do |f|
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

          @user_config_file = @full_config.notation_get("atmos.user_config") || @user_config_file
          @user_config_file = File.expand_path(@user_config_file)
          user_config_file_data = load_file(@user_config_file)
          temp_settings = create_settings(config_merge(@full_config, user_config_file_data, [@user_config_file]), finalize: true)

          @full_config = load_config_sources(File.dirname(config_file), @full_config, *Array(temp_settings.notation_get("atmos.config_sources")))
          @full_config = load_remote_config_sources(@full_config, *Array(temp_settings.notation_get("atmos.remote_config_sources")))

          @full_config['provider'] = provider_name = @full_config['provider'] || 'aws'

          @full_config = load_submap(File.dirname(config_file), 'providers', provider_name, @full_config)
          @full_config = load_submap(File.dirname(config_file), 'environments', atmos_env, @full_config)

          @full_config = config_merge(@full_config, user_config_file_data, [@user_config_file])

          conf = create_settings(@full_config, finalize: true)

          # hash emptied out to allow GC of all loaded file contents
          @included_configs = {}

          conf

        end
      end

      def load_file(file, config=SettingsHash.new, &block)
        if File.exist?(file)
          logger.debug("Loading atmos config file #{file}")
          contents = File.read(file)
          config = load_config(file, contents, config, &block)
        else
          logger.debug   "Could not find an atmos config file at: #{file}"
        end

        config
      end

      def load_config(location, yml_string, config=SettingsHash.new, &block)
        data = YAML.load(yml_string)

        if ! data.is_a?(Hash)
          logger.debug("Skipping invalid atmos config (not hash-like): #{location}")
        else
          data = SettingsHash.new(data)
          data = block.call(data) if block
          # if lhs has a override ^, then it loses it when rhs gets merged in, which breaks things for subsequent merges
          config = config_merge(config, data, [location])
          @included_configs[location] = yml_string
        end

        config
      end

      def create_settings(config, finalize: true)
        builtins = {
            atmos_env: atmos_env,
            atmos_working_group: working_group,
            atmos_version: VERSION
        }

        global = SettingsHash.new(config.reject {|k, v| ['providers', 'environments'].include?(k) })
        conf = config_merge(global, builtins, ["builtins"])
        conf = finalize_merge(conf) if finalize

        conf.error_resolver = ->(statement) { find_config_error(statement) }
        conf.enable_expansion = true

        conf
      end

      def find_config_error(statement)
        filename = nil
        line = 0

        @included_configs.each do |location, contents|
          current_line = 0
          contents.each_line do |line|
            current_line += 1
            if line.include?(statement)
              filename = location
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
