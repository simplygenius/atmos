require_relative '../atmos'
require_relative '../atmos/ui'
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

      TEMPLATES_SPEC_FILE = 'templates.yml'
      TEMPLATES_ACTIONS_FILE = 'templates.rb'

      attr_reader :name, :location

      def initialize(name, location)
        @name = name
        @location = location
        @configs = {}
        @actions = {}
      end

      def to_s
        "#{name} (#{location})"
      end

      def template_names
        template_dirs.keys.sort
      end

      def template_dir(name)
        template_dirs[name]
      end

      def directory
        if @directory_resolved
          @directory
        else
          @directory_resolved = true
          @directory = expand_location
        end
      end

      def template_actions_path(name)
        File.join(template_dir(name), TEMPLATES_ACTIONS_FILE)
      end

      def template_actions(name)
        @actions[name] ||= (File.exist?(template_actions_path(name)) ? File.read(template_actions_path(name)) : "")
      end

      def template_config_path(name)
        File.join(template_dir(name), TEMPLATES_SPEC_FILE)
      end

      def template_config(name)
        @configs[name] ||= begin
          data = File.read(template_config_path(name))
          YAML.load(data) || {}
        end
      end

      def template_dependencies(name)
        Array(template_config(name)['dependent_templates'])
      end

      def template_optional(name)
        template_config(name)['optional'] || {}
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

              sourcepath_dir = local_template_path
              logger.debug("Using git sourcepath: #{local_template_path}")
            rescue => e
              msg = "Could not read from git archive, ignoring sourcepath: #{name}, #{location}"
              logger.log_exception(e, msg, level: :debug)
              logger.warn(msg)
            end

          elsif sourcepath =~ /.zip$/

            begin
              logger.debug("Cloning zip archive to tmpdir")

              open(sourcepath, 'rb') do |io|
                Zip::File.open_buffer(io) do |zip_file|
                  zip_file.each do |f|
                    fpath = File.join(tmpdir, f.name)
                    f.extract(fpath)
                  end
                end
              end

              local_template_path = File.join(tmpdir, template_subdir)
              sourcepath_dir = local_template_path
              logger.debug("Using zip sourcepath: #{local_template_path}")
            rescue => e
              msg = "Could not read from zip archive, ignoring sourcepath: #{name}, #{location}"
              logger.log_exception(e, msg, level: :debug)
              logger.warn(msg)
            end

          end

        else

          logger.debug("Using local sourcepath: #{sourcepath}")
          sourcepath_dir = File.expand_path(sourcepath)

        end

        sourcepath_dir
      end
      
      def template_dirs
        @template_dirs ||= begin
          directory = expand_location
          template_dirs = {}
          if directory && Dir.exist?(directory)

            Find.find(directory) do |f|
              Find.prune if File.basename(f) =~  /(^\.)|svn|CVS|git/

              template_spec = File.join(f, TEMPLATES_SPEC_FILE)
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

    end

  end
end
