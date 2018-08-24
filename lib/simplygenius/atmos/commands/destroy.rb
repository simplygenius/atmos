require_relative 'terraform'

module SimplyGenius
  module Atmos
    module Commands

      class Destroy < Terraform

        def self.description
          "Runs terraform destroy"
        end

        def execute
          @terraform_arguments.insert(0, "destroy")
          super
        end

      end

    end
  end
end
