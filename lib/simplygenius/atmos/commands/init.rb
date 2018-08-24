require_relative 'terraform'

module SimplyGenius
  module Atmos
    module Commands

      class Init < Terraform

        def self.description
          "Runs terraform init"
        end

        def execute
          @terraform_arguments.insert(0, "init")
          super
        end

      end

    end
  end
end
