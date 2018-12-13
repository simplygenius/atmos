require_relative '../../atmos'
require_relative 'output_filter'

module SimplyGenius
  module Atmos
    module Plugins

      class PromptNotify < OutputFilter

        def filter(data, flushing: false)
          if data =~ /^[\e\[\dm\s]*Enter a value:[\e\[\dm\s]*$/
            notify(message: "Terraform is waiting for user input")
          end
          data
        end

      end

    end
  end
end
