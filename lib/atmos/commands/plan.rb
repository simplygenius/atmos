require 'atmos'
require 'atmos/commands/terraform'

module Atmos::Commands

  class Plan < Atmos::Commands::Terraform

    def self.description
      "Runs terraform plan"
    end

    def execute
      @terraform_arguments.insert(0, "plan")
      super
    end

  end

end
