require_relative 'terraform'
require 'fileutils'
require 'os'

module SimplyGenius
  module Atmos
    module Commands

      class Init < Terraform
        include FileUtils

        def self.description
          "Runs terraform init"
        end

        def execute
          @terraform_arguments.insert(0, "init")
          super

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

      end

    end
  end
end
