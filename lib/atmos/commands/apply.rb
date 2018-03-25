require 'atmos/commands/terraform'

module Atmos::Commands

  class Apply < Atmos::Commands::Terraform

    def self.description
      "Runs terraform apply"
    end

    def execute
      args = ["apply"]
      args << "--get-modules" unless Atmos.config["disable_auto_modules"].to_s == "true"
      @terraform_arguments.insert(0, *args)
      super
    end

  end

end
