require_relative 'generate'

module SimplyGenius
  module Atmos
    module Commands

      class New < Generate

        def self.description
          "Sets up a new atmos project in the current directory"
        end

        def execute
          template_list << "new"
          super
        end

      end

    end
  end
end
