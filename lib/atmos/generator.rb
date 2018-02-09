require 'gem_logger'
require 'thor'
require 'find'

module Atmos

  # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
  class Generator < Thor

    include Thor::Actions
    no_commands { include GemLogger::LoggerSupport }

    source_root File.expand_path('../../../templates', __FILE__)

    def self.valid_templates
      Dir.entries(self.source_root).delete_if {|e| e =~  /(^\.)|svn|CVS/ }.sort
    end

    desc "generate TEMPLATE", ""

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

    def find_dependencies(name, seen=[])
      template_dir = File.join(self.class.source_root, name, '')
      unless File.directory?(template_dir)
        raise Thor::Error.new("Invalid template #{name}, use one of #{self.class.valid_templates.join(', ')}")
      end

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
      template_dir = File.join(self.class.source_root, name, '')
      unless File.directory?(template_dir)
        raise Thor::Error.new("Invalid template #{name}, use one of #{self.class.valid_templates.join(', ')}")
      end

      template_conf = load_template_config(template_dir)

      extra_generator_steps_file = File.join(template_dir, 'templates.rb')

      Find.find(template_dir) do |f|
        Find.prune if f == File.join(template_dir, 'templates.yml')  # don't copy over templates.yml
        Find.prune if f == extra_generator_steps_file # don't copy over templates.rb

        template_rel = f.gsub(/#{template_dir}/, '')
        source_rel = f.gsub(/#{self.class.source_root}\//, '')
        dest_rel   = source_rel.gsub(/^#{name}\//, '')

        # Only include optional files when their conditions eval to true
        optional = template_conf['optional'][template_rel] rescue nil
        Find.prune if optional && ! eval(optional)

        if File.directory?(f)
          empty_directory(dest_rel)
        else
          copy_file(source_rel, dest_rel)
          src_mode = File.stat(f).mode
          dest_mode = File.stat(File.join(destination_root, dest_rel)).mode
          chmod(dest_rel, src_mode) if src_mode != dest_mode
        end
      end

      if File.exist? extra_generator_steps_file
        eval File.read(extra_generator_steps_file), binding, extra_generator_steps_file
      end
    end

    def load_template_config(template_dir)
      YAML.load(File.read(File.join(template_dir, 'templates.yml'))) rescue {}
    end

  end

end
