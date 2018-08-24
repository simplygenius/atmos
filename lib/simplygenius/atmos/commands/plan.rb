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
          args << "--get-modules" unless Atmos.config["disable_auto_modules"].to_s == "true"
          @terraform_arguments.insert(0, *args)
          super
        end

      end

    end
  end
end
