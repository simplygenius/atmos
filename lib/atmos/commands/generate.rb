require 'gem_logger'
require 'clamp'
require 'atmos/generator'
require 'atmos/utils'

module Atmos::Commands

  # From https://github.com/rubber/rubber/blob/master/lib/rubber/commands/vulcanize.rb
  class Generate < Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      # Format templates into comma-separated paragraph with limt of 70 characters per line
      lines = ['']
      Atmos::Generator.valid_templates.each do |template_name|
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

      Atmos::Utils.clean_indent(<<-EOF
        Installs configuration templates used by atmos to create infrastructure
        resources e.g.
        
          atmos generate aws-vpc
        
        where TEMPLATE is one of:
        
        #{lines.join("\n")}
      EOF
      )
    end

    option ["-f", "--force"], :flag, "Overwrite files that already exist"
    option ["-n", "--dryrun"], :flag, "Run but do not make any changes"
    option ["-q", "--quiet"], :flag, "Supress status output"
    option ["-s", "--skip"], :flag, "Skip files that already exist"

    parameter "TEMPLATE ...", "atmos template(s)" do |arg|
      invalid = [arg].flatten - Atmos::Generator.valid_templates
      if invalid.size == 0
        arg
      else
        raise ArgumentError.new "Templates #{arg.inspect} don't exist"
      end
    end

    def execute
      g = Atmos::Generator.new([],
                            :force => force?,
                            :pretend => dryrun?,
                            :quiet => quiet?,
                            :skip => skip?)
      g.generate(template_list)
    end

  end

end
