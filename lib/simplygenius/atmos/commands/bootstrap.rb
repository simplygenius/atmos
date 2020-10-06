require_relative 'base_command'

module SimplyGenius
  module Atmos
    module Commands

      class Bootstrap < BaseCommand

        def self.description
          "Sets up the initial aws account for use by atmos"
        end

        option ["-f", "--force"],
               :flag, "forces bootstrap\n"

        def execute
          orig_config = Atmos.config
          Atmos.config = Config.new(Atmos.config.atmos_env, 'bootstrap')

          tf_init_dir = File.join(Atmos.config.tf_working_dir, '.terraform')
          tf_initialized = File.exist?(tf_init_dir)
          backend_initialized = File.exist?(File.join(tf_init_dir, 'terraform.tfstate'))

          rebootstrap_msg = <<~EOF
            Bootstrap should only be performed when provisioning an account for the first
            time.  Try 'atmos terraform init'
          EOF

          if !force? && tf_initialized
            signal_usage_error(rebootstrap_msg)
          end

          Atmos.config.provider.auth_manager.authenticate(ENV, bootstrap: true) do |auth_env|
            begin
              exe = TerraformExecutor.new(process_env: auth_env)

              skip_backend = true
              skip_secrets = true
              if backend_initialized
                skip_backend = false
                skip_secrets = false
              end

              # Cases
              # 1) bootstrap of new account - success
              # 2) repeating bootstrap of new account due to failure partway - success
              # 3) try to rebootstrap existing account on fresh checkout - should fail trying to create resources of same name, check output for this?
              # 4) bootstrap new account with no-default secrets

              # Need to init before we can create the resources to store state in bootstrap
              exe.run("init", "-input=false", "-lock=false",
                      skip_backend: true, skip_secrets: true)

              # Bootstrap to create the resources needed to store state
              exe.run("apply", "-input=false",
                      skip_backend: true, skip_secrets: true)

              # Need to init to setup the backend state after we create the resources
              # to store state in bootstrap
              exe.run("init", "-input=false", "-force-copy", skip_secrets: true)

              # Might as well init the non-bootstrap case as well once the state
              # storage has been setup in bootstrap
              Atmos.config = orig_config
              exe = TerraformExecutor.new(process_env: auth_env)
              exe.run("init", "-input=false", skip_secrets: true)

            rescue TerraformExecutor::ProcessFailed => e
              logger.error(e.message)
              logger.error(rebootstrap_msg)
              exit(1)
            end
          end
        end

      end

    end
  end
end
