require_relative '../../../atmos'
require 'aws-sdk-organizations'

module Atmos
  module Providers
    module Aws

      class AccountManager
        include GemLogger::LoggerSupport
        include FileUtils

        def initialize(provider)
          @provider = provider
        end

        def create_account(env, name: nil, email: nil)
          result = {}
          org = ::Aws::Organizations::Client.new
          resp = nil
          name ||= "Atmos #{env} account"

          begin
            logger.info "Looking up organization"
            resp = org.describe_organization()
            logger.debug "Described organization: #{resp.to_h}"
          rescue ::Aws::Organizations::Errors::AWSOrganizationsNotInUseException
            logger.info "Organization doesn't exist, creating"
            resp = org.create_organization()
            logger.debug "Created organization: #{resp.to_h}"
          end

          if email.blank?
            master_email = resp.organization.master_account_email
            email = master_email.sub('@', "+#{env}@")
          end
          result[:email] = email
          result[:name] = name


          begin
            logger.info "Creating account named #{name}"
            resp = org.create_account(account_name: name, email: email)
          rescue ::Aws::Organizations::Errors::FinalizingOrganizationException
            logger.info "Waiting to retry account creation as the organization needs to finalize"
            logger.info "This will eventually succeed after receiving a"
            logger.info "'Consolidated Billing verification' email from AWS"
            logger.info "You can leave this running or cancel and restart later."
            sleep 60
            retry
          end

          logger.debug "Created account: #{resp.to_h}"

          status_id = resp.create_account_status.id
          status = resp.create_account_status.state
          account_id = resp.create_account_status.account_id

          while status =~ /in_progress/i
            logger.info "Waiting for account creation to complete, status: #{status}"
            resp = org.describe_create_account_status(create_account_request_id: status_id)
            logger.debug("Account creation status check: #{resp.to_h}")
            status = resp.create_account_status.state
            account_id = resp.create_account_status.account_id
            sleep 5
          end

          if status =~ /failed/i
            logger.error "Failed to create account: #{resp.create_account_status.failure_reason}"
            exit(1)
          end

          result[:account_id] = account_id

          return result
        end

      end

    end
  end
end

