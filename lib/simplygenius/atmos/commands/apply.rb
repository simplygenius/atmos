require_relative 'terraform'

module SimplyGenius
  module Atmos
    module Commands

      class Apply < Terraform

        def self.description
          "Runs terraform apply"
        end

        def execute
          args = ["apply"]
          args << "--get-modules" unless Atmos.config["atmos.terraform.disable_auto_modules"].to_s == "true"
          @terraform_arguments.insert(0, *args)
          super
        end

      end

    end
  end
end
