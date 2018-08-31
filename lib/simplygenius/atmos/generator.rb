require_relative '../atmos'
require_relative '../atmos/ui'
require 'thor'
require 'find'

module SimplyGenius
  module Atmos

    # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
    class Generator

      include GemLogger::LoggerSupport
      include UI

      def initialize(*sourcepaths, **opts)
        @sourcepaths = sourcepaths
        if opts.has_key?(:dependencies)
          @dependencies = opts.delete(:dependencies)
        else
          @dependencies = true
        end
        @thor_opts = opts
        @thor_generators = {}
        @resolved_templates = {}
      end

      # TODO: store/track installed templates in a file in target repo

      def generate(template_names)
          seen = Set.new
          Array(template_names).each do |template_name|

            template_dependencies = find_dependencies(template_name)
            template_dependencies << template_name

            template_dependencies.each do |tname|
              apply_template(tname) unless seen.include?(tname)
              seen << tname
            end

          end
        end

      protected

      # TODO: allow fully qualifying dependent templates by source name, e.g. atmos-recipes:scaffold

      def sourcepath_for(name)
        @resolved_templates[name] ||= begin
          sps = @sourcepaths.select do |sp|
            sp.template_names.include?(name)
          end

          sp = nil
          if sps.size == 0
            raise ArgumentError.new("Could not find template: #{name}")
          elsif sps.size > 1
            if @thor_opts[:force]
              sp = sps.first
            else
              sp_names = sps.collect(&:name)
              sp_names.collect {|n| sp_names.count(n)}

              choice = choose do |menu|
                menu.prompt = "Which source for template '#{name}'? "
                sp_names.each { |n| menu.choice(n) }
                menu.default = sp_names.first
              end
              sp = sps[sp_names.index(choice)]
            end
            logger.info "Using source '#{sp.name}' for template '#{name}'"
          else
            sp = sps.first
          end

          sp
        end
      end

      def find_dependencies(name, seen=[])
        return [] unless @dependencies

        if seen.include?(name)
            seen << name
            raise ArgumentError.new("Circular template dependency: #{seen.to_a.join(" => ")}")
        end
        seen << name

        sp = sourcepath_for(name)
        template_dependencies = Set.new(sp.template_dependencies(name))

        template_dependencies.clone.each do |dep|
          template_dependencies.merge(find_dependencies(dep, seen.dup))
        end

        return template_dependencies.to_a
      end

      def apply_template(name)
        sp = sourcepath_for(name)

        @thor_generators[sp] ||= begin
          Class.new(ThorGenerator) do
            source_root sp.directory
          end
        end

        gen = @thor_generators[sp].new(sp, **@thor_opts)
        gen.apply(name)
        gen # makes testing easier by giving a handle to thor generator instance
      end

      class ThorGenerator < Thor

        include Thor::Actions

        def initialize(source_path, **opts)
          @source_path = source_path
          super([], **opts)
          source_path
        end

        no_commands do
          include GemLogger::LoggerSupport
          include UI

          def apply(name)
            template_dir = @source_path.template_dir(name)
            path = @source_path.directory

            logger.debug("Applying template '#{name}' from '#{template_dir}' in sourcepath '#{path}'")

            Find.find(template_dir) do |f|
              Find.prune if f == @source_path.template_config_path(name)  # don't copy over templates.yml
              Find.prune if f == @source_path.template_actions_path(name) # don't copy over templates.rb

              # Using File.join(x, '') to ensure trailing slash to make sure we end
              # up with a relative path
              template_rel = f.gsub(/#{File.join(template_dir, '')}/, '')
              source_rel = f.gsub(/#{File.join(path, '')}/, '')
              dest_rel   = source_rel.gsub(/^#{File.join(name, '')}/, '')

              # prune non-directories at top level (the top level directory is the
              # template dir itself)
              if f !~ /\// && ! File.directory?(f)
                Find.prune
              end

              # Only include optional files when their conditions eval to true
              optional = @source_path.template_optional(name)[template_rel]
              if optional
                exclude = ! eval(optional)
                logger.debug("Optional template '#{template_rel}' with condition: '#{optional}', excluding=#{exclude}")
                Find.prune if exclude
              end

              logger.debug("Template '#{source_rel}' => '#{dest_rel}'")
              if File.directory?(f)
                empty_directory(dest_rel)
              else
                copy_file(source_rel, dest_rel, mode: :preserve)
              end
            end

            eval @source_path.template_actions(name), binding, @source_path.template_actions_path(name)
          end

        end

        desc "raw_config <yml_filename>", "Loads yml file"
        def raw_config(yml_file)
          @raw_configs ||= {}
          @raw_configs[yml_file] ||= SettingsHash.new((YAML.load_file(yml_file) rescue {}))
        end

        desc "add_config <yml_filename> <key> <value> [additive: true]", "Adds config to yml file if not there (additive=true)"
        def add_config(yml_file, key, value, additive: true)
          new_yml = SettingsHash.add_config(yml_file, key, value, additive: additive)
          create_file yml_file, new_yml
          @raw_configs.delete(yml_file) if @raw_configs
        end

        desc "get_config <yml_filename> <key>", "Gets value of key (dot-notation for nesting) from yml file"
        def get_config(yml_file, key)
          config = raw_config(yml_file)
          config.notation_get(key)
        end

        desc "config_present? <yml_filename> <key> <value>", "Tests if key is in yml file and equal to value if supplied"
        def config_present?(yml_file, key, value=nil)
          val = get_config(yml_file, key)

          result = val.present?
          if value && result
            if val.is_a?(Array)
              result = Array(value).all? {|v| val.include?(v) }
            else
              result = (val == value)
            end
          end

          return result
        end

        desc "new_keys? <src_yml_filename> <dest_yml_filename>", "Tests if src/dest yml have differing top level keys"
        def new_keys?(src_yml_file, dest_yml_file)
          src = raw_config(src_yml_file).keys.sort
          dest = raw_config(dest_yml_file).keys.sort
          (src - dest).size > 0
        end

      end

    end

  end
end
