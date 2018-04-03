require 'atmos'
require 'aws-sdk-core'
require 'aws-sdk-iam'
require 'json'
require 'atmos/utils'
require 'atmos/ui'
require 'atmos/otp'

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

        def authenticate(system_env, **opts, &block)

          profile = system_env['AWS_PROFILE']
          key = system_env['AWS_ACCESS_KEY_ID']
          secret = system_env['AWS_SECRET_ACCESS_KEY']
          if profile.blank? && (key.blank? || secret.blank?)
            logger.warn("An aws profile or key/secret should be supplied via the environment")
          end

          # Handle bootstrapping a new env account.  Newly created organization
          # accounts only have the default role that can only be assumed by an
          # iam user, so use that as the target for assume_role, and the root
          # check below will ensure iam user
          assume_role_name = nil
          if opts[:bootstrap] && Atmos.config.atmos_env != 'ops'
            # TODO: do this hack better
            assume_role_name = Atmos.config["auth.bootstrap_assume_role_name"]
          else
            assume_role_name = opts[:role] || Atmos.config["auth.assume_role_name"]
          end
          account_id = Atmos.config.account_hash[Atmos.config.atmos_env].to_s
          role_arn = "arn:aws:iam::#{account_id}:role/#{assume_role_name}"

          user_name = nil
          begin
            sts = ::Aws::STS::Client.new
            resp = sts.get_caller_identity
            arn_pieces = resp.arn.split(":")
            user_name = arn_pieces.last.split("/").last

            # root credentials can't assume role, but they should have full
            # access for the current account, so proceed (e.g. for bootstrap).
            if arn_pieces.last == "root"

              # We check the account of the caller to prevent root user of ops
              # account from bootstrapping an env account, but still allow a
              # root user of the env account itself to be able to bootstrap
              # (i.e. to allow not organizational accounts to bootstrap using
              # their root user)
              if arn_pieces[-2] != account_id
                logger.error <<~EOF
                  Account doesn't match credentials.  Bootstrapping a new
                  account should be done as an iam user from the ops account or
                  using credentials for a root user of the env account.
                EOF
                exit(1)
              end

              # Should only use root credentials for  bootstrap, and thus we
              # won't have role requirement for mfa, etc, even if root account
              # uses mfa for login.  Thus skip all the other stuff, to
              # encourage/force use of non-root accounts for normal use
              logger.warn("Using aws root credentials - should only be neccessary for bootstrap")
              return block.call(Hash[system_env])
            end

          rescue ::Aws::STS::Errors::ServiceError => e
            logger.error "Could not discover aws credentials"
            exit(1)
          end

          auth_needed = true
          cache_key = "#{user_name}-#{assume_role_name}"
          credentials = read_auth_cache[cache_key]

          if credentials.present?
            logger.debug("Session cache present, checking expiration...")
            expiration = Time.parse(credentials['expiration'])
            session_renew_interval = (session_duration / 4).to_i

            if Time.now > expiration
              logger.debug "Session cache is expired, performing normal auth"
              auth_needed = true
            elsif Time.now > (expiration - session_renew_interval)
              begin
                logger.info "Session approaching expiration, renewing..."
                credentials = assume_role(role_arn, credentials: credentials)
                auth_needed = false
              rescue => e
                logger.info "Failed to renew credentials using session cache, reason: #{e.message}"
                auth_needed = true
              end
            else
              logger.debug "Session cache is current, skipping auth"
              auth_needed = false
            end
          end

          if auth_needed
            begin
              logger.info "No active session cache, authenticating..."

              credentials = assume_role(role_arn)
              write_auth_cache(cache_key => credentials)

            rescue ::Aws::STS::Errors::AccessDenied => e
              if e.message !~ /explicit deny/
                logger.debug "Access Denied, reason: #{e.message}"
              end

              logger.info "Normal auth failed, checking for mfa"

              iam = ::Aws::IAM::Client.new
              response = iam.list_mfa_devices(user_name: user_name)
              mfa_serial = response.mfa_devices.first.try(:serial_number)
              token = nil
              if mfa_serial.present?

                token = Atmos::Otp.instance.generate(user_name)
                if token.nil?
                  token = ask("Enter token to retry with mfa: ")
                else
                  logger.info "Used integrated atmos mfa to generate token"
                end

                if token.blank?
                  logger.error "A MFA token must be supplied"
                  exit(1)
                end

              else
                logger.error "MFA is not setup for your account, retry after doing so"
                exit(1)
              end

              credentials = assume_role(role_arn, serial_number: mfa_serial, token_code: token)
              write_auth_cache(cache_key => credentials)

            end
          end

          process_env = {}
          process_env['AWS_ACCESS_KEY_ID'] = credentials['access_key_id']
          process_env['AWS_SECRET_ACCESS_KEY'] = credentials['secret_access_key']
          process_env['AWS_SESSION_TOKEN'] = credentials['session_token']
          logger.debug("Calling authentication target with env: #{process_env.inspect}")
          block.call(Hash[system_env].merge(process_env))
        end

        private

        def session_duration
          @session_duration ||= (Atmos.config["auth.session_duration"] || 3600).to_i
        end

        def assume_role(role_arn, **opts)
          # use Aws::AssumeRoleCredentials ?
          if opts[:credentials]
            c = opts.delete(:credentials)
            creds = ::Aws::Credentials.new(
                c[:access_key_id], c[:secret_access_key], c[:session_token]
            )
            client_opts = {credentials: creds}
          else
            client_opts = {}
          end
          sts = ::Aws::STS::Client.new(client_opts)
          params = {
              duration_seconds: session_duration,
              role_session_name: "Atmos",
              role_arn: role_arn
          }.merge(opts)
          logger.debug("Assuming role: #{params}")
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
          data = JSON.parse(File.read(auth_cache_file)) rescue {}
          Atmos::Utils::SymbolizedMash.new(data)
        end

      end

    end
  end
end