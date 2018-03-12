require 'atmos'
require 'aws-sdk-core'
require 'aws-sdk-iam'
require 'json'
require 'atmos/utils'
require 'atmos/ui'

module Atmos
  module Providers
    module Aws

      class AuthManager
        include GemLogger::LoggerSupport
        include FileUtils
        include Atmos::UI

        def initialize(provider)
          @provider = provider
        end

        def authenticate(system_env, &block)

          profile = system_env['AWS_PROFILE']
          key = system_env['AWS_ACCESS_KEY_ID']
          secret = system_env['AWS_SECRET_ACCESS_KEY']
          if profile.blank? && (key.blank? || secret.blank?)
            logger.warn("An aws profile or key/secret should be supplied via the environment")
          end

          begin
            sts = ::Aws::STS::Client.new
            resp = sts.get_caller_identity
            arn_pieces = resp.arn.split(":")

            # root credentials can't assume role, but they should have full
            # access for the current account, so proceed (e.g. for bootstrap).
            if arn_pieces.last == "root"
              # TODO: not sure about root assuming role to another account, so have a sanity check here
              account_id = Atmos.config.account_hash[Atmos.config.atmos_env].to_s
              if arn_pieces[-2] != account_id
                logger.error "Account doesn't match credentials"
                exit(1)
              end

              # Should only use root credentials for  bootstrap, and thus we
              # won't have role requirement for mfa, etc, even if root account
              # uses mfa for login.  Thus skip all the other stuff, to
              # encourage/force use of non-root accounts for normal use
              logger.warn("Using aws root credentials - should only be neccessary for bootstrap")
              return block.call(system_env)
            end

          rescue ::Aws::STS::Errors::ServiceError => e
            logger.error "Could not discover aws credentials"
            exit(1)
          end

          credentials = read_auth_cache
          auth_needed = !(credentials.present? && Time.parse(credentials['expiration']) > Time.now)

          session_renew_interval = session_duration / 4
          if !auth_needed && Time.parse(credentials['expiration']) - session_renew_interval < Time.now
            logger.info "Session approaching expiration, renewing..."
            credentials = assume_role(credentials: credentials)
            auth_needed = false
          end

          if auth_needed
            begin
              logger.info "No active session cache, authenticating..."

              credentials = assume_role
              write_auth_cache(credentials)

            rescue ::Aws::STS::Errors::AccessDenied => e
              if e.message !~ /explicit deny/
                logger.debug "Access Denied, reason: #{e.message}"
              end

              logger.info "Normal auth failed, checking for mfa"

              iam = ::Aws::IAM::Client.new
              response = iam.list_mfa_devices
              mfa_serial = response.mfa_devices.first.try(:serial_number)
              token = nil
              if mfa_serial.present?

                token = ask("Enter token to retry with mfa: ")

                if token.blank?
                  logger.error "A MFA token must be supplied"
                  exit(1)
                end
              else
                logger.error "MFA is not setup for your account, retry after doing so"
                exit(1)
              end

              credentials = assume_role(serial_number: mfa_serial, token_code: token)
              write_auth_cache(credentials)

            end
          end

          process_env = {}
          process_env['AWS_ACCESS_KEY_ID'] = credentials['access_key_id']
          process_env['AWS_SECRET_ACCESS_KEY'] = credentials['secret_access_key']
          process_env['AWS_SESSION_TOKEN'] = credentials['session_token']
          logger.debug("Calling authentication target with env: #{process_env.inspect}")
          block.call(Hash.new(system_env).merge(process_env))
        end

        private

        def session_duration
          @session_duration ||= (Atmos.config["auth.session_duration"] rescue 3600).to_i
        end

        def assume_role(**opts)
          # use Aws::AssumeRoleCredentials ?
          if opts[:credentials]
             client_opts = {credentials: opts.delete(:credentials)}
          else
            client_opts = {}
          end
          sts = ::Aws::STS::Client.new(client_opts)
          params = {
              duration_seconds: session_duration,
              role_session_name: "Atmos",
              role_arn: Atmos.config["auth.assume_role_name"]
          }.merge(opts)
          resp = sts.assume_role(params)
          return Atmos::Utils::SymbolizedMash.new(resp.credentials.to_h)
        end

        def auth_cache_file
          File.join(Atmos.config.auth_cache_dir, 'aws-assume-role.json')
        end

        def write_auth_cache(h)
          File.open(auth_cache_file, 'w') do |f|
            f.puts(JSON.pretty_generate(h))
          end
        end

        def read_auth_cache
          Atmos::Utils::SymbolizedMash.new(JSON.parse(File.read(auth_cache_file))) rescue nil
        end

      end

    end
  end
end