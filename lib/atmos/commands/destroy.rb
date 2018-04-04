require_relative 'terraform'

module Atmos::Commands

  class Destroy < Atmos::Commands::Terraform

    def self.description
      "Runs terraform destroy"
    end

    def execute
      @terraform_arguments.insert(0, "destroy")
      super
    end

  end

end
