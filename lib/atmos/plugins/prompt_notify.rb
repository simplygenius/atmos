require_relative '../../atmos'
require_relative 'output_filter'

module Atmos::Plugins
  class PromptNotify < OutputFilter

    def filter(data)
      if data =~ /^[\e\[\dm\s]*Enter a value:[\e\[\dm\s]*$/
        notify(message: "Terraform is waiting for user input")
      end
      data
    end

  end
end
