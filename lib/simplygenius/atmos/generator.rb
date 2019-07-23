require_relative '../atmos'
require_relative '../atmos/ui'
require 'thor'
require 'find'

module SimplyGenius
  module Atmos

    # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
    class Generator

      include GemLogger::LoggerSupport

      attr_reader :visited_templates

      def initialize(**opts)
        if opts.has_key?(:dependencies)
          @dependencies = opts.delete(:dependencies)
        else
          @dependencies = true
        end
        @thor_opts = opts
        @thor_generators = {}
        @resolved_templates = {}
        @visited_templates = []
      end

      def generate(*template_names, context: {})
        seen = Set.new

        template_names.each do |template_name|

          # clone since we are mutating context and can be called from within a
          # template, walk_deps also clones
          tmpl = SourcePath.find_template(template_name)
          tmpl.clone.context.merge!(context)

          if @dependencies
            deps = tmpl.walk_dependencies.to_a
          else
            deps = [tmpl]
          end

          deps.each do |dep_tmpl|
            seen_tmpl = [dep_tmpl.name, dep_tmpl.scoped_context]
            unless seen.include?(seen_tmpl)
              apply_template(dep_tmpl)
            end
            seen <<  seen_tmpl
          end

        end

        # TODO: return all context so the calling template can see answers to
        # template questions to use in customizing its output (e.g. service
        # needs cluster name and ec2 backed state)
        return visited_templates
      end

      def apply_template(tmpl)
        @thor_generators[tmpl.source] ||= Class.new(ThorGenerator) do
          source_root tmpl.source.directory
        end

        gen = @thor_generators[tmpl.source].new(tmpl, self, **@thor_opts)
        gen.apply
        visited_templates << tmpl

        gen # makes testing easier by giving a handle to thor generator instance
      end

      protected

      class ThorGenerator < Thor

        include Thor::Actions
        attr_reader :tmpl, :parent

        def initialize(tmpl, parent, **opts)
          @tmpl = tmpl
          @parent = parent
          super([], **opts)
        end

        no_commands do

          include GemLogger::LoggerSupport
          include UI

          def apply
            template_dir = tmpl.directory
            path = tmpl.source.directory

            logger.debug("Applying template '#{tmpl.name}' from '#{template_dir}' in sourcepath '#{path}'")

            Find.find(template_dir) do |f|
              next if f == template_dir  # don't create a directory for the template dir itself, but don't prune so we recurse
              Find.prune if f == tmpl.config_path  # don't copy over templates.yml
              Find.prune if f == tmpl.actions_path # don't copy over templates.rb

              # Using File.join(x, '') to ensure trailing slash to make sure we end
              # up with a relative path
              template_rel = f.gsub(/#{File.join(template_dir, '')}/, '')
              source_rel = f.gsub(/#{File.join(path, '')}/, '')
              dest_rel   = source_rel.gsub(/^#{File.join(tmpl.name, '')}/, '')

              # Only include optional files when their conditions eval to true
              optional = tmpl.optional[template_rel]
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

            eval tmpl.actions, binding, tmpl.actions_path
          end

          def context
            tmpl.context
          end

          def scoped_context
            tmpl.scoped_context
          end

          def lookup_context(varname)
            varname.blank? ? nil: tmpl.scoped_context[varname]
          end

          def track_context(varname, value)
            varname.blank? || value.nil? ? nil : tmpl.scoped_context[varname] = value
          end

          def respond_to_missing?(method_name, *args)
            scoped_context.respond_to_missing?(method_name, *args)
          end

          def method_missing(method_name, *args, &blk)
            scoped_context.method_missing(method_name, *args, &blk)
          end

        end

        desc "ask <question string> [varname: name]", "Asks a question, allowing context to provide answer using varname"
        def ask(question, answer_type = nil, varname: nil, &details)
          result = lookup_context(varname)
          if result.nil?
            result = super(question, answer_type, &details)
          end
          track_context(varname, result)
          result
        end

        desc "agree <question string> [varname: name]", "Asks a Y/N question, allowing context to provide answer using varname"
        def agree(question, character = nil, varname: nil, &details)
          result = lookup_context(varname)
          if result.nil?
            result = super(question, character, &details)
          end
          result = !!result
          track_context(varname, result)
          result
        end

        desc "choose menu_block [varname: name]", "Provides a menu with choices, allowing context to provide answer using varname"
        def choose(*items, varname: nil, &details)
          result = lookup_context(varname)
          if result.nil?
            result = super(*items, &details)
          end
          track_context(varname, result)
          result
        end

        desc "generate <tmpl_name> [context_hash]", "Generates the given template with optional context"
        def generate(name, ctx: context)
          parent.generate(name, context: ctx.clone)
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

        desc "new_keys? <src_yml_filename> <dest_yml_filename>", "Tests if src yml has top level keys not present in dest yml"
        def new_keys?(src_yml_file, dest_yml_file)
          src = raw_config(src_yml_file).keys.sort
          dest = raw_config(dest_yml_file).keys.sort
          (src - dest).size > 0
        end

      end

    end

  end
end
