require_relative '../atmos'
require_relative '../atmos/ui'
require_relative '../atmos/template'
require 'find'
require 'tmpdir'
require 'fileutils'
require 'git'
require 'open-uri'
require 'zip'

module SimplyGenius
  module Atmos

    class SourcePath
      include GemLogger::LoggerSupport

      class_attribute :registry, default: {}
      attr_reader :name, :location

      def self.clear_registry
        registry.clear
        @resolved_templates.clear if @resolved_templates
      end

      def self.register(name, location)
        sp = SourcePath.new(name, location)
        raise ArgumentError.new("Source paths must be uniquely named: #{sp}") if registry[name]
        registry[name] = sp
      end

      def self.find_template(template_name)
        @resolved_templates ||= {}
        @resolved_templates[template_name] ||= begin
          tmpls = registry.collect {|name, sp| sp.template(template_name) }.compact

          if tmpls.size == 0
            raise ArgumentError.new("Could not find the template: #{template_name}")
          elsif tmpls.size > 1
            raise ArgumentError.new("Template names must be unique, #{template_name} exists in multiple sources: #{tmpls.collect(&:source)}")
          end

          tmpls.first
        end
      end

      def initialize(name, location)
        @name = name
        @location = location
      end

      def to_s
        "#{name} (#{location})"
      end

      def to_h
        SettingsHash.new({name: name, location: location})
      end

      def directory
        if @directory_resolved
          @directory
        else
          @directory_resolved = true
          @directory = expand_location
        end
      end

      def template_names
        templates.keys.sort
      end

      def template(name)
        templates[name]
      end

      protected

      def expand_location
        sourcepath_dir = nil
        sourcepath = location
        if sourcepath =~ /(\.git)|(\.zip)(#.*)?$/

          logger.debug("Using archive sourcepath")

          tmpdir = Dir.mktmpdir("atmos-templates-")
          at_exit { FileUtils.remove_entry(tmpdir) }

          template_subdir = ''
          if sourcepath =~ /([^#]*)#([^#]*)/
            sourcepath = Regexp.last_match[1]
            template_subdir = Regexp.last_match[2]
            logger.debug("Using archive subdirectory for templates: #{template_subdir}")
          end

          if sourcepath =~ /.git$/

            begin
              logger.debug("Cloning git archive to tmpdir")

              g = Git.clone(sourcepath, 'atmos-checkout', depth: 1, path: tmpdir)
              local_template_path = File.join(g.dir.path, template_subdir)

              sourcepath_dir = File.expand_path(local_template_path)
              logger.debug("Using git sourcepath: #{sourcepath_dir}")
            rescue => e
              msg = "Could not read from git archive, ignoring sourcepath: #{name}, #{location}"
              logger.log_exception(e, msg, level: :debug)
              logger.warn(msg)
            end

          elsif sourcepath =~ /.zip$/

            begin
              logger.debug("Cloning zip archive to tmpdir")

              URI.open(sourcepath, 'rb') do |io|
                Zip::File.open_buffer(io) do |zip_file|
                  zip_file.each do |f|
                    fpath = File.join(tmpdir, f.name)
                    f.extract(fpath)
                  end
                end
              end

              local_template_path = File.join(tmpdir, template_subdir)
              sourcepath_dir = File.expand_path(local_template_path)
              logger.debug("Using zip sourcepath: #{sourcepath_dir}")
            rescue => e
              msg = "Could not read from zip archive, ignoring sourcepath: #{name}, #{location}"
              logger.log_exception(e, msg, level: :debug)
              logger.warn(msg)
            end

          end

        else

          sourcepath_dir = File.expand_path(sourcepath)
          logger.debug("Using local sourcepath: #{sourcepath_dir}")

        end

        sourcepath_dir
      end
      
      def template_dirs
        @template_dirs ||= begin
          template_dirs = {}
          if directory && Dir.exist?(directory)

            Find.find(directory) do |f|
              Find.prune if File.basename(f) =~  /(^\.)|svn|CVS|git/

              template_spec = File.join(f, Template::TEMPLATES_SPEC_FILE)
              if File.exist?(template_spec)
                template_name = f.sub(/^#{directory}\//, '')

                if template_dirs[template_name]
                  # safety, this should never get hit
                  raise "A single source path cannot have duplicate templates: #{f}"
                end
                template_dirs[template_name] = f
                Find.prune
              end
            end

          else

            logger.warn("Sourcepath directory does not exist for location: #{location}, #{directory}")

          end

          template_dirs
        end
      end

      def templates
        @templates ||= Hash[template_dirs.collect do |tname, dir|
          [tname, Template.new(tname, dir, self)]
        end]
      end

    end

  end
end
