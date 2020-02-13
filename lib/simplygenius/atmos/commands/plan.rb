require_relative 'terraform'

module SimplyGenius
  module Atmos
    module Commands

      class Plan < Terraform

        def self.description
          "Runs terraform plan"
        end

        def execute
          args = ["plan"]
          args << "--get-modules" unless Atmos.config["atmos.terraform.disable_auto_modules"].to_s == "true"
          @terraform_arguments.insert(0, *args)

          self.auto_init = true

          super
        end

      end

    end
  end
end
