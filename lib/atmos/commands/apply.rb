require 'atmos'
require 'atmos/commands/terraform'

module Atmos::Commands

  class Apply < Atmos::Commands::Terraform

    def self.description
      "Runs terraform apply"
    end

    def execute
      @terraform_arguments.insert(0, "apply")
      super
    end

  end

end
