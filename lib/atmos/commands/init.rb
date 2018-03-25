require 'atmos/commands/terraform'

module Atmos::Commands

  class Init < Atmos::Commands::Terraform

    def self.description
      "Runs terraform init"
    end

    def execute
      @terraform_arguments.insert(0, "init")
      super
    end

  end

end
