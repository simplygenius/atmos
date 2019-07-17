require_relative '../../atmos'
require_relative 'output_filter'
require_relative '../../atmos/terraform_executor'

module SimplyGenius
  module Atmos
    module Plugins

      class LockDetection < SimplyGenius::Atmos::Plugins::OutputFilter

        def filter(data, flushing: false)
          if data =~ /^[\e\[\dm\s]*Lock Info:[\e\[\dm\s]*$/
            @lock_detected = true
          end
          if data =~ /^[\e\[\dm\s]*ID:\s*([a-f0-9\-]+)[\e\[\dm\s]*$/
            @lock_id = $1
          end
          data
        end

        def close
          if @lock_detected && @lock_id.present?
            clear_lock = agree("Terraform lock detected, would you like to clear it? ") {|q| q.default = 'n' }
            if clear_lock
              logger.info "Clearing terraform lock with id: #{@lock_id}"
              te = TerraformExecutor.new(process_env: context[:process_env])
              te.run("force-unlock", "-force", @lock_id)
            end
          end
        end

      end

    end
  end
end

