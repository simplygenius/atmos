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

      def generate(template_names, context=SettingsHash.new)
        seen = Set.new
        context = SettingsHash.new(context) unless context.kind_of?(SettingsHash)

        Array(template_names).each do |template_name|

          tmpl = SettingsHash.new.merge(context).merge({template: template_name})

          walk_dependencies(tmpl).each do |tmpl|
            tname = tmpl[:template]
            seen_tmpl = (tmpl.notation_get(context_path(tname)) || SettingsHash.new).merge({template: tname})
            apply_template(tmpl) unless seen.include?(seen_tmpl)
            seen <<  seen_tmpl
          end

        end
      end

      def context_path(name)
        name.gsub('-', '_').gsub('/', '.')
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

      # depth first iteration of dependencies
      def walk_dependencies(tmpl, seen=Set.new)
        Enumerator.new do |yielder|
          tmpl = SettingsHash.new(tmpl) unless tmpl.kind_of?(SettingsHash)
          name = tmpl[:template]

          if @dependencies
            if seen.include?(name)
                seen << name
                raise ArgumentError.new("Circular template dependency: #{seen.to_a.join(" => ")}")
            end
            seen << name

            sp = sourcepath_for(name)
            template_dependencies = sp.template_dependencies(name)

            template_dependencies.each do |dep|
              child = dep.clone
              child_name = child.delete(:template)
              child = child.merge(tmpl).merge(template: child_name)
              walk_dependencies(child, seen.dup).each {|d| yielder << d }
            end
          end

          yielder << tmpl
        end
      end

      def apply_template(tmpl)
        tmpl = SettingsHash.new(tmpl) unless tmpl.kind_of?(SettingsHash)
        name = tmpl[:template]
        context = tmpl
        sp = sourcepath_for(name)

        @thor_generators[sp] ||= begin
          Class.new(ThorGenerator) do
            source_root sp.directory
          end
        end

        gen = @thor_generators[sp].new(name, context, sp, self, **@thor_opts)
        gen.apply
        gen # makes testing easier by giving a handle to thor generator instance
      end

      class ThorGenerator < Thor

        include Thor::Actions
        attr_reader :name, :context, :context_path, :source_path, :parent

        def initialize(name, context, source_path, parent, **opts)
          @name = name
          @context = context
          @source_path = source_path
          @parent = parent
          @context_path = parent.context_path(name)
          super([], **opts)
        end

        no_commands do

          include GemLogger::LoggerSupport
          include UI

          def apply
            template_dir = @source_path.template_dir(name)
            path = @source_path.directory

            logger.debug("Applying template '#{name}' from '#{template_dir}' in sourcepath '#{path}'")

            Find.find(template_dir) do |f|
              next if f == template_dir  # don't create a directory for the template dir itself, but don't prune so we recurse
              Find.prune if f == @source_path.template_config_path(name)  # don't copy over templates.yml
              Find.prune if f == @source_path.template_actions_path(name) # don't copy over templates.rb

              # Using File.join(x, '') to ensure trailing slash to make sure we end
              # up with a relative path
              template_rel = f.gsub(/#{File.join(template_dir, '')}/, '')
              source_rel = f.gsub(/#{File.join(path, '')}/, '')
              dest_rel   = source_rel.gsub(/^#{File.join(name, '')}/, '')

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

          def lookup_context(varname)
            varname.blank? ? nil: context.notation_get("#{context_path}.#{varname}")
          end
        end

        desc "ask <question string> [varname: name]", "Asks a question, allowing context to provide answer using varname"
        def ask(question, answer_type = nil, varname: nil, &details)
          result = lookup_context(varname)
          if result.nil?
            result = super(question, answer_type, &details)
          end
          result
        end

        desc "agree <question string> [varname: name]", "Asks a Y/N question, allowing context to provide answer using varname"
        def agree(question, character = nil, varname: nil, &details)
          result = lookup_context(varname)
          if result.nil?
            result = super(question, character, &details)
          end
          !!result
        end

        desc "generate <tmpl_name> [context_hash]", "Generates the given template with optional context"
        def generate(name, ctx: context)
          parent.send(:generate, [name], ctx)
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
