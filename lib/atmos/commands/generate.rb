require 'gem_logger'
require 'clamp'
require 'atmos/generator_factory'
require 'atmos/utils'

module Atmos::Commands

  # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
  class Generate < Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      Atmos::Utils.clean_indent(<<-EOF
        Installs configuration templates used by atmos to create infrastructure
        resources e.g.
        
          atmos generate aws-vpc
        
        use --list to get a list of the template names for a given sourceroot
      EOF
      )
    end

    option ["-f", "--force"], :flag, "Overwrite files that already exist"
    option ["-n", "--dryrun"], :flag, "Run but do not make any changes"
    option ["-q", "--quiet"], :flag, "Supress status output"
    option ["-s", "--skip"], :flag, "Skip files that already exist"
    option ["-l", "--list"],
           :flag, "list available templates\n"
    option ["-p", "--sourcepath"],
           "PATH", "find templates at given path or github url\n",
           multivalued: true

    parameter "TEMPLATE ...", "atmos template(s)", required: false

    def execute
      signal_usage_error "template name is required" if template_list.blank? && ! list?

      # Always search for templates against the bundled templates directory
      sourcepath_list.insert(0, File.expand_path('../../../../templates', __FILE__))

      g = Atmos::GeneratorFactory.create(sourcepath_list,
                                         force: force?,
                                         pretend: dryrun?,
                                         quiet: quiet?,
                                         skip: skip?)
      if list?
        puts "Valid templates are:"
        puts list_templates(g, template_list)
      else
        g.generate(template_list)
      end

    end

    def list_templates(generator, name_filters)
      # Format templates into comma-separated paragraph with limt of 70 characters per line
      filtered_names = generator.valid_templates.select do |name|
        name_filters.blank? || name_filters.any? {|f| name =~ /#{f}/ }
      end

      lines = ['']
      filtered_names.each do |template_name|
        line = lines.last
        if line.size == 0
          line << template_name
        elsif line.size + template_name.size > 68
          line << ','
          lines << template_name # new line
        else
          line << ", " + template_name
        end
      end

      return lines
    end

  end

end
