require 'atmos'
require 'thor'
require 'find'

module Atmos

  # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
  class Generator < Thor

    include Thor::Actions

    no_commands do

      include GemLogger::LoggerSupport

      TEMPLATES_SPEC_FILE = 'templates.yml'
      TEMPLATES_ACTIONS_FILE = 'templates.rb'

      def self.valid_templates
        all_entries = []
        source_paths_for_search.collect do |path|
          entries = []
          if Dir.exist?(path)
            Find.find(path) do |f|
              Find.prune if File.basename(f) =~  /(^\.)|svn|CVS/

              template_spec = File.join(f, TEMPLATES_SPEC_FILE)
              if File.exist?(template_spec)
                entries << f.sub(/^#{path}\//, '')
                Find.prune
              end
            end
            all_entries << entries.sort
          else
            logger.warn("Sourcepath does not exist: #{path}")
          end
        end

        return all_entries.flatten
      end

      def valid_templates
        self.class.valid_templates
      end

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

    end

    protected

    def template_dir(name)
      template_dir = nil
      source_path = nil
      source_paths.each do |sp|
        potential_template_dir = File.join(sp, name, '')
        template_spec = File.join(sp, name, TEMPLATES_SPEC_FILE)
        if File.exist?(template_spec) && File.directory?(potential_template_dir)
          template_dir = potential_template_dir
          source_path = sp
          break
        end
      end

      unless template_dir.present?
        raise ArgumentError.new("Invalid template #{name}, use one of: #{valid_templates.join(', ')}")
      end

      return template_dir, source_path
    end

    def find_dependencies(name, seen=[])
      template_dir, source_path = template_dir(name)

      if seen.include?(name)
          seen << name
          raise ArgumentError.new("Circular template dependency: #{seen.to_a.join(" => ")}")
      end
      seen << name

      template_conf = load_template_config(template_dir)
      template_dependencies = Set.new(Array(template_conf['dependent_templates'] || []))

      template_dependencies.clone.each do |dep|
        template_dependencies.merge(find_dependencies(dep, seen.dup))
      end

      return template_dependencies.to_a
    end

    def apply_template(name)
      template_dir, source_path = template_dir(name)

      template_conf = load_template_config(template_dir)

      extra_generator_steps_file = File.join(template_dir, TEMPLATES_ACTIONS_FILE)

      Find.find(template_dir) do |f|
        Find.prune if f == File.join(template_dir, TEMPLATES_SPEC_FILE)  # don't copy over templates.yml
        Find.prune if f == extra_generator_steps_file # don't copy over templates.rb

        template_rel = f.gsub(/#{template_dir}/, '')
        source_rel = f.gsub(/#{source_path}\//, '')
        dest_rel   = source_rel.gsub(/^#{name}\//, '')

        # prune non-directories at top level (the top level directory is the
        # template dir itself)
        if f !~ /\// && ! File.directory?(f)
          Find.prune
        end

        # Only include optional files when their conditions eval to true
        optional = template_conf['optional'][template_rel] rescue nil
        Find.prune if optional && ! eval(optional)

        if File.directory?(f)
          empty_directory(dest_rel)
        else
          copy_file(source_rel, dest_rel, mode: :preserve)
        end
      end

      if File.exist? extra_generator_steps_file
        eval File.read(extra_generator_steps_file), binding, extra_generator_steps_file
      end
    end

    def load_template_config(template_dir)
      YAML.load(File.read(File.join(template_dir, 'templates.yml'))) || {} rescue {}
    end

    def raw_config(yml_file)
      @raw_configs ||= {}
      @raw_configs[yml_file] ||= SettingsHash.new((YAML.load_file(yml_file) rescue {}))
    end

    def add_config(yml_file, key, value, additive: true)
      new_yml = SettingsHash.add_config(yml_file, key, value, additive: additive)
      create_file yml_file, new_yml
      @raw_configs.delete(yml_file) if @raw_configs
    end

    def get_config(yml_file, key)
      config = raw_config(yml_file)
      config.notation_get(key)
    end

    def config_present?(yml_file, key, value=nil)
      val = get_config(yml_file, key)

      result = val.present?
      if value && result
        if val.is_a?(Array)
          result = val.include?(value)
        else
          result = (val == value)
        end
      end

      return result
    end

    # TODO make a context object for these actions, and populate it with things
    # like template_dir from within apply
    def new_keys?(src_yml_file, dest_yml_file)
      src = raw_config(src_yml_file).keys.sort
      dest = raw_config(dest_yml_file).keys.sort
      (src - dest).size > 0
    end

  end

end
