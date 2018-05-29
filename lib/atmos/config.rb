require_relative '../atmos'
require_relative '../atmos/settings_hash'
require_relative '../atmos/provider_factory'
require 'yaml'
require 'fileutils'
require 'find'

module Atmos
  class Config
    include GemLogger::LoggerSupport
    include FileUtils

    attr_accessor :atmos_env, :root_dir,
                  :config_file, :configs_dir,
                  :tmp_root

    def initialize(atmos_env)
      @atmos_env = atmos_env
      @root_dir = File.expand_path(Dir.pwd)
      @config_file = File.join(root_dir, "config", "atmos.yml")
      @configs_dir = File.join(root_dir, "config", "atmos")
      @tmp_root = File.join(root_dir, "tmp")
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
      @provider ||= Atmos::ProviderFactory.get(self[:provider])
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

    def tf_working_dir(group='default')
      @tf_working_dir ||= {}
      @tf_working_dir[group] ||= begin
        dir = File.join(tmp_dir, 'tf', group)
        logger.debug("Terraform working dir: #{dir}")
        mkdir_p(dir)
        dir
      end
    end

    private

    INTERP_PATTERN = /(\#\{([^\}]+)\})/

    # TODO: do this better by writing own hash and/or custom merge logic that is not constrained by Hashie
    ADDITIVE_MERGE = Proc.new do |key, this_val, other_val|
      # Only recurses deeply if vals are both hash, then call this with keys from hash contents, not the key for the
      # hash itself

      # Warn if user fat fingered config
      unless this_val.is_a?(other_val.class) || other_val.is_a?(this_val.class)
        logger.warn("Different types in deep merge for `#{key}`: #{this_val.class}, #{other_val.class}")
      end

      result = other_val

      if other_val.is_a?(Array)
        # also see HACK in expand()
        if other_val.first == "^"
          result = other_val[1..-1]
        else
          result = this_val + other_val
        end
      end

      result
    end

    def load
      @config ||= begin

        logger.debug("Atmos env: #{atmos_env}")

        if ! File.exist?(config_file)
          logger.warn "Could not find an atmos config file at: #{config_file}"
          # raise RuntimeError.new("Could not find an atmos config file at: #{config_file}")
        end

        logger.debug("Loading atmos config file #{config_file}")
        @full_config = SettingsHash.new((YAML.load_file(config_file) rescue Hash.new))

        if Dir.exist?(configs_dir)
         logger.debug("Loading atmos config files from #{configs_dir}")
         Find.find(configs_dir) do |f|
           if f =~ /\.ya?ml/i
             logger.debug("Loading atmos config file: #{f}")
             h = SettingsHash.new(YAML.load_file(f))
             @full_config = @full_config.deep_merge(h, &ADDITIVE_MERGE)
           end
         end
        else
         logger.debug("Atmos config dir doesn't exist: #{configs_dir}")
        end

        @full_config['provider'] = provider_name = @full_config['provider'] || 'aws'
        global = SettingsHash.new(@full_config.reject {|k, v| ['environments', 'providers'].include?(k) })
        begin
          prov = @full_config.deep_fetch(:providers, provider_name)
        rescue
          logger.debug("No provider config found for '#{provider_name}'")
          prov = {}
        end

        begin
          env = @full_config.deep_fetch(:environments, atmos_env)
        rescue
          logger.debug("No environment config found for '#{atmos_env}'")
          env = {}
        end

        conf = global.deep_merge(prov, &ADDITIVE_MERGE).
            deep_merge(env, &ADDITIVE_MERGE).
            deep_merge({
                           atmos_env: atmos_env,
                           atmos_version: Atmos::VERSION
                       }, &ADDITIVE_MERGE)
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

      configs = []
      configs << config_file if File.exist?(config_file)
      if Dir.exist?(configs_dir)
        Find.find(configs_dir) do |f|
          if f =~ /\.ya?ml/i
            configs << f
          end
        end
      end

      configs.each do |c|
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
