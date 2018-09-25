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
            
              atmos generate aws/vpc
            
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
               :flag, "list available templates"
        option ["-u", "--update"],
               :flag, "update all installed templates\n"
        option ["-p", "--sourcepath"],
               "PATH", "search for templates using given sourcepath",
               multivalued: true
        option ["-r", "--[no-]sourcepaths"],
               :flag, "clear sourcepaths from template search\n", default: true
        option ["-c", "--context"],
               "CONTEXT", "provide context variables (dot notation)",
               multivalued: true

        parameter "TEMPLATE ...", "atmos template(s)", required: false

        def execute
          signal_usage_error "template name is required" if template_list.blank? && ! list? && !update?

          sourcepath_list.each do |sp|
            SourcePath.register(File.basename(sp), sp)
          end

          if sourcepaths?

            # don't want to fail for new repo
            if  Atmos.config && Atmos.config.is_atmos_repo?
              Atmos.config['atmos.template_sources'].try(:each) do |item|
                SourcePath.register(item.name, item.location)
              end
            end

            # Always search for templates against the bundled templates directory
            SourcePath.register('bundled', File.expand_path('../../../../../templates', __FILE__))

          end

          if list?
            logger.info "Valid templates are:"
            SourcePath.registry.each do |spname, sp|
              logger.info("\tSourcepath #{sp}")
              filtered_names = sp.template_names.select do |name|
                template_list.blank? || template_list.any? {|f| name =~ /#{f}/ }
              end
              filtered_names.each {|n| logger.info ("\t\t#{n}")}
            end
          else
            g = Generator.new(force: force?,
                                 pretend: dryrun?,
                                 quiet: quiet?,
                                 skip: skip?,
                                 dependencies: dependencies?)

            begin

              context = SettingsHash.new
              context_list.each do |c|
                key, value = c.split('=', 2)
                context.notation_put(key, value)
              end

              if update?
                # this isn't 100% foolproof, but is a convenience that should help for most cases

                filtered_templates = state[:visited_templates].select do |vt|
                  template_list.blank? || template_list.any? {|n| vt[:name] =~ /#{n}/ }
                end

                sps = filtered_templates.collect(&:source).uniq
                sps.each do |src|
                  spname = src[:name]
                  sploc = src[:location]

                  existing_sp = SourcePath.registry[spname]
                  if existing_sp
                    if existing_sp.location != sploc
                      logger.warn("Saved sourcepath location differs from that in configuration")
                      logger.warn(" #{spname} -> saved=#{sploc} configured=#{existing_sp.location}")
                      logger.warn(" consider running with --no-sourcepaths")
                    end
                  else
                    sp = SourcePath.register(spname, sploc)
                    logger.warn("Saved state contains a source path missing from configuration: #{sp}")
                  end
                end

                filtered_templates.each do |vt|
                  name = vt[:name]
                  ctx = vt[:context]
                  spname = vt[:source][:name]
                  sp = SourcePath.registry[spname]
                  tmpl = sp.template(name)
                  tmpl.scoped_context.merge!(ctx) if ctx
                  tmpl.context.merge!(context)
                  g.apply_template(tmpl)
                end
              else
                g.generate(*template_list, context: context)
              end

              save_state(g.visited_templates, template_list)

            rescue  ArgumentError => e
              logger.error(e.message)
              exit 1
            end
          end

        end

        def state_file
          @state_file ||= Atmos.config["atmos.generate.state_file"]
        end

        def state
          @state ||= begin
            if state_file.present?
              path = File.expand_path(state_file)
              yml_hash = {}
              if File.exist?(path)
                yml_hash = YAML.load_file(path)
              end
              SettingsHash.new(yml_hash)
            else
              SettingsHash.new
            end
          end
        end

        def save_state(visited_templates, entrypoint_template_names)
          if state_file.present?
            visited_state = []
            visited_templates.each do |tmpl|
              visited_tmpl = tmpl.to_h
              visited_tmpl[:context] = tmpl.scoped_context.to_h
              visited_state << visited_tmpl
            end

            state[:visited_templates] ||= []
            state[:visited_templates].concat(visited_state)
            state[:visited_templates].sort! {|h1, h2| h1[:name] <=> h2[:name] }.uniq!

            state[:entrypoint_templates] ||= []
            state[:entrypoint_templates].concat(entrypoint_template_names)
            state[:entrypoint_templates].sort!.uniq!

            File.write(state_file, YAML.dump(state.to_hash))
          end
        end

      end

    end
  end
end
