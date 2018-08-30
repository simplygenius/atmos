require_relative 'base_command'
require_relative '../../atmos/source_path'
require_relative '../../atmos/generator'
require_relative '../../atmos/utils'

module SimplyGenius
  module Atmos
    module Commands

      # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
      class Generate < BaseCommand

        def self.description
          <<~EOF
            Installs configuration templates used by atmos to create infrastructure
            resources e.g.
            
              atmos generate aws-vpc
            
            use --list to get a list of the template names for a given sourceroot
          EOF
        end

        option ["-f", "--force"],
               :flag, "Overwrite files that already exist"
        option ["-n", "--dryrun"],
               :flag, "Run but do not make any changes"
        option ["-q", "--quiet"],
               :flag, "Supress status output"
        option ["-s", "--skip"],
               :flag, "Skip files that already exist"
        option ["-d", "--[no-]dependencies"],
               :flag, "Walk dependencies, or not", default: true
        option ["-l", "--list"],
               :flag, "list available templates\n"
        option ["-p", "--sourcepath"],
               "PATH", "find templates at given path or github url\n",
               multivalued: true

        parameter "TEMPLATE ...", "atmos template(s)", required: false

        def execute
          signal_usage_error "template name is required" if template_list.blank? && ! list?

          sourcepaths = []
          sourcepath_list.each do |sp|
            sourcepaths << SourcePath.new(File.basename(sp), sp)
          end

          # don't want to fail for new repo
          if  Atmos.config && Atmos.config.is_atmos_repo?
            Atmos.config['template_sources'].try(:each) do |item|
              sourcepaths << SourcePath.new(item.name, item.location)
            end
          end

          # Always search for templates against the bundled templates directory
          sourcepaths << SourcePath.new('bundled', File.expand_path('../../../../../templates', __FILE__))

          if list?
            logger.info "Valid templates are:"
            sourcepaths.each do |sp|
              logger.info("\tSourcepath #{sp}")
              filtered_names = sp.template_names.select do |name|
                template_list.blank? || template_list.any? {|f| name =~ /#{f}/ }
              end
              filtered_names.each {|n| logger.info ("\t\t#{n}")}
            end
          else
            g = Generator.new(*sourcepaths,
                                 force: force?,
                                 pretend: dryrun?,
                                 quiet: quiet?,
                                 skip: skip?,
                                 dependencies: dependencies?)
            begin
              g.generate(template_list)
            rescue  ArgumentError => e
              logger.error(e.message)
              exit 1
            end
          end

        end

      end

    end
  end
end
