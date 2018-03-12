require 'atmos'
require 'thor'
require 'find'

module Atmos

  # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
  class Generator < Thor

    include Thor::Actions

    no_commands do

      include GemLogger::LoggerSupport

      def self.valid_templates
        source_paths_for_search.collect do |path|
          entries = Dir.entries(path).select do |e|
            p = File.join(path, e)
            File.directory?(p) && e !~  /(^\.)|svn|CVS/
          end
          entries.sort
        end.flatten
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
        if File.directory?(potential_template_dir)
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

      extra_generator_steps_file = File.join(template_dir, 'templates.rb')

      Find.find(template_dir) do |f|
        Find.prune if f == File.join(template_dir, 'templates.yml')  # don't copy over templates.yml
        Find.prune if f == extra_generator_steps_file # don't copy over templates.rb

        template_rel = f.gsub(/#{template_dir}/, '')
        source_rel = f.gsub(/#{source_path}\//, '')
        dest_rel   = source_rel.gsub(/^#{name}\//, '')

        # prune non-directories at top level
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
      YAML.load(File.read(File.join(template_dir, 'templates.yml'))) rescue {}
    end

    def add_yaml(file, path, value, additive: true)
      config = Atmos::Config::SettingsHash.new(YAML.load_file(file))
      config_level = config
      path.each_with_index do |k, i|
        if i == path.length - 1
          config_level[k] = value
        else
          next_level = config_level[k]
          if next_level
            config_level = next_level
            next
          else
            next_level = {}
            config_level[k] = next_level
            next
          end
        end
      end
    end

  end

end
