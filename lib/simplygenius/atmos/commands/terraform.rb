require_relative 'base_command'
require_relative '../../atmos/terraform_executor'

module SimplyGenius
  module Atmos
    module Commands

      class Terraform < BaseCommand
        include FileUtils

        attr_accessor :auto_init

        def self.description
          "Runs terraform"
        end

        # override so we can pass all options/flags/parameters directly to
        # terraform instead of having clamp parse them
        def parse(arguments)
          @terraform_arguments = arguments
        end

        def init_automatically(auth_env, get_modules)
          tf_init_dir = File.join(Atmos.config.tf_working_dir, '.terraform')
          backend_initialized = File.exist?(File.join(tf_init_dir, 'terraform.tfstate'))
          auto_init_enabled = Atmos.config["atmos.terraform.auto_init"].to_s == "true"

          if auto_init && auto_init_enabled && ! backend_initialized
            exe = TerraformExecutor.new(process_env: auth_env)
            exe.run("init", get_modules: get_modules.present?)
            init_shared_plugins
          end
        end

        def init_shared_plugins
          if ! Atmos.config["atmos.terraform.disable_shared_plugins"]
            home_dir = OS.windows? ? File.join("~", "Application Data") : "~"
            shared_plugins_dir = File.expand_path(File.join(home_dir,".terraform.d", "plugins"))
            logger.debug("Updating shared terraform plugins dir: #{shared_plugins_dir}")
            mkdir_p(shared_plugins_dir)
            terraform_plugins_dir = File.join(Atmos.config.tf_working_dir,'recipes', '.terraform', 'plugins')
            if File.exist?(terraform_plugins_dir)
              cp_r("#{terraform_plugins_dir}/.", shared_plugins_dir)
            end
          end
        end

        def execute

          unless Atmos.config.is_atmos_repo?
            signal_usage_error <<~EOF
              Atmos can only run terraform from a location configured for atmos. 
              Have you run atmos init?"
            EOF
          end

          Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
            begin
              get_modules = @terraform_arguments.delete("--get-modules")

              init_automatically(auth_env, get_modules)

              exe = TerraformExecutor.new(process_env: auth_env)
              exe.run(*@terraform_arguments, get_modules: get_modules.present?)
            rescue TerraformExecutor::ProcessFailed => e
              logger.error(e.message)
            end
          end
        end

      end

    end
  end
end
