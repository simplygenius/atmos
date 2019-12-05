require_relative '../atmos'
require_relative '../atmos/ipc'
require_relative '../atmos/ui'
require 'open3'
require 'fileutils'
require 'find'
require 'climate_control'

module SimplyGenius
  module Atmos

    class TerraformExecutor
      include GemLogger::LoggerSupport
      include FileUtils
      include UI

      class ProcessFailed < RuntimeError; end

      def initialize(process_env: ENV)
        @process_env = process_env
        recipe_config_path = "recipes.#{Atmos.config.working_group}"
        @recipes = Array(Atmos.config[recipe_config_path])
        if @recipes.blank?
          logger.warn("Check your configuration, there are no recipes in '#{recipe_config_path}'")
        end
        @compat11 = Atmos.config['atmos.terraform.compat11'].to_s == "true"
      end

      def run(*terraform_args, skip_backend: false, skip_secrets: false, get_modules: false, output_io: nil)
        setup_working_dir(skip_backend: skip_backend)

        if get_modules
          logger.debug("Getting modules")
          get_modules_io = StringIO.new
          begin
            execute("get", output_io: get_modules_io)
          rescue TerraformExecutor::ProcessFailed => e
            logger.info(get_modules_io.string)
            raise
          end
        end

        return execute(*terraform_args, skip_secrets: skip_secrets, output_io: output_io)
      end

      private

      def tf_cmd(*args)
        ['terraform'] + args
      end

      def execute(*terraform_args, skip_secrets: false, output_io: nil)
        cmd = tf_cmd(*terraform_args)
        logger.debug("Running terraform: #{cmd.join(' ')}")

        env = Hash[@process_env]
        if ! skip_secrets
          begin
            env = env.merge(secrets_env)
          rescue => e
            logger.debug("Secrets not available: #{e}")
          end
        end

        # TF 0.12 deprecates values for undeclared vars in an tfvars file, so
        # put it in env instead as they claim that to be the expected way to do
        # so and will continue to work
        # https://github.com/hashicorp/terraform/issues/19424
        env = env.merge(atmos_env)

        # lets tempfiles created by subprocesses be easily found by users
        env['TMPDIR'] = Atmos.config.tmp_dir

        # Lets terraform communicate back to atmos, e.g. for UI notifications
        ipc = Ipc.new(Atmos.config.tmp_dir)

        IO.pipe do |stdout, stdout_writer|
          IO.pipe do |stderr, stderr_writer|

            stdout_writer.sync = stderr_writer.sync = true

            stdout_filters = Atmos.config.plugin_manager.output_filters(:stdout, {process_env: @process_env, working_group: Atmos.config.working_group})
            stderr_filters = Atmos.config.plugin_manager.output_filters(:stderr, {process_env: @process_env, working_group: Atmos.config.working_group})

            stdout_thr = pipe_stream(stdout, output_io.nil? ? $stdout : output_io, &stdout_filters.filter_block)
            stderr_thr = pipe_stream(stderr, output_io.nil? ? $stderr : output_io, &stderr_filters.filter_block)

            ipc.listen do |sock_path|

              if Atmos.config['atmos.ipc.disable']
                # Using : as the command makes execution of ipc from the
                # terraform side a no-op in both cases of how we call it.  This
                # way, terraform execution continues to work when IPC is disabled
                # command = "$ATMOS_IPC_CLIENT <json_string>"
                # program = ["sh", "-c", "$ATMOS_IPC_CLIENT"]
                env['ATMOS_IPC_CLIENT'] = ":"
              else
                env['ATMOS_IPC_SOCK'] = sock_path
                env['ATMOS_IPC_CLIENT'] = ipc.generate_client_script
              end

              # Was unable to get piping to work with stdin for some reason.  It
              # worked in simple case, but started to fail when terraform config
              # got more extensive.  Thus, using spawn to redirect stdin from the
              # terminal direct to terraform, with IO.pipe to copy the outher
              # streams.  Maybe in the future we can completely disconnect stdin
              # and have atmos do the output parsing and stdin prompting
              pid = spawn(env, *cmd,
                          chdir: tf_recipes_dir,
                          :out=>stdout_writer, :err=> stderr_writer, :in => :in)

              logger.debug("Terraform started with pid #{pid}")
              begin
                Process.wait(pid)
              rescue Interrupt
                logger.warn "Got SIGINT, sending to terraform pid=#{pid}"

                Process.kill("INT", pid)
                Process.wait(pid)

                logger.debug "Completed signal cleanup"
                exit!(1)
              end

            end

            stdout_writer.close
            stderr_writer.close
            stdout_thr.join
            stderr_thr.join
            stdout_filters.close
            stderr_filters.close

            status = $?.exitstatus
            logger.debug("Terraform exited: #{status}")
            if status != 0
              raise ProcessFailed.new "Terraform exited with non-zero exit code: #{status}"
            end

          end
        end

      end

      def setup_working_dir(skip_backend: false)
        clean_links
        link_support_dirs
        link_recipes
        setup_backend(skip_backend)
      end

      def setup_backend(skip_backend=false)
        backend_file = File.join(tf_recipes_dir, 'atmos-backend.tf.json')
        backend_config = (Atmos.config["backend"] || {}).clone

        if backend_config.present? && ! skip_backend
          logger.debug("Writing out terraform state backend config")

          backend_type = backend_config.delete("type")

          backend = {
              "terraform" => {
                  "backend" => {
                      backend_type => backend_config
                  }
              }
          }

          File.write(backend_file, JSON.pretty_generate(backend))
        else
          logger.debug("Clearing terraform state backend config")
          File.delete(backend_file) if File.exist?(backend_file)
        end
      end

      def homogenize_encode(v)
        case v
        when nil
          @compat11 ? "" : v
        else
          v
        end
      end

      # terraform requires all values within a map to have the same type, so
      # flatten the map - nested maps get expanded into the top level one, with
      # their keys being appended with underscores, and lists get joined with
      # "," so we end up with a single hash with homogenous types
      #
      def homogenize_for_terraform(obj, prefix="")
        if obj.is_a? Hash
          result = {}
          obj.each do |k, v|
            ho = homogenize_for_terraform(v, "#{prefix}#{k}_")
            if ho.is_a? Hash
              result = result.merge(ho)
            else
              result["#{prefix}#{k}"] = homogenize_encode(ho)
            end
          end
          return result
        elsif obj.is_a? Array
          result = []
          obj.each do |o|
            ho = homogenize_for_terraform(o, prefix)
            if ho.is_a? Hash
              result << ho.collect {|k, v| "#{k}=#{homogenize_encode(v)}"}.join(";")
            else
              result << homogenize_encode(ho)
            end
          end
          return result.join(",")
        else
          return homogenize_encode(obj)
        end
      end

      def encode_tf_env_value(v)
        case v
        when nil
          @compat11 ? "" : JSON.generate(v)
        when Numeric, String, TrueClass, FalseClass
          v.to_s
        when Hash
          if @compat11
            hcl_hash =v.collect {|k, v| %Q("#{k.to_s}"="#{encode_tf_env_value(v)}") }.join(",")
            "{#{hcl_hash}}"
          else
            JSON.generate(v)
          end
        else
          JSON.generate(v)
        end
      end

      def encode_tf_env(hash)
        result = {}
        hash.each do |k, v|
          result["TF_VAR_#{k}"] = encode_tf_env_value(v)
        end
        return result
      end

      def tf_recipes_dir
        @tf_recipes_dir ||= begin
          dir = File.join(Atmos.config.tf_working_dir, 'recipes')
          logger.debug("Tf recipes dir: #{dir}")
          mkdir_p(dir)
          dir
        end
      end

      def secrets_env
        # NOTE use an auto-deleting temp file if passing secrets through env ends
        # up being problematic
        # TODO fix the need for CC - TE calls for secrets which needs auth in
        # ENV, so kinda clunk to have to do both CC and pass the env in
        ClimateControl.modify(@process_env) do
          secrets = Atmos.config.provider.secret_manager.to_h
          env_secrets = encode_tf_env(secrets)
          return env_secrets
        end
      end

      # TODO: Add ability to declare variables as well as set them.  May need to
      # inspect existing tf to find all declared vars so we don't double declare
      def atmos_env
        # A var value in the env is ignored if a variable declaration doesn't exist for it in a tf file.  Thus,
        # as a convenience to allow everything from atmos to be referenceable, we put everything from the atmos_config
        # in a homogenized hash named atmos_config which is declared by the atmos scaffolding.  For variables which are
        # declared, we also merge in atmos config with only the hash values homogenized (vs the entire map) so that hash
        # variables if declared in terraform can be managed from yml, set here and accessed from terraform
        #
        homogenized_config = homogenize_for_terraform(Atmos.config.to_h)
        homogenized_values = Hash[Atmos.config.to_h.collect {|k, v| [k, v.is_a?(Hash) ? homogenize_for_terraform(v) : v]}]
        var_hash = {
            all_env_names: Atmos.config.all_env_names,
            account_ids: Atmos.config.account_hash,
            atmos_config: homogenized_config
        }
        var_hash = var_hash.merge(homogenized_values)

        env_hash = encode_tf_env(var_hash)

        # write out a file so users have some visibility into vars passed in -
        # mostly useful for debugging
        File.open(File.join(tf_recipes_dir, 'atmos-tfvars.env'), 'w') do |f|
          env_hash.each do |k, v|
            f.puts("#{k}='#{v}'")
          end
        end

        return env_hash
      end

      def clean_links
        Find.find(Atmos.config.tf_working_dir) do |f|
          Find.prune if f =~ /\/.terraform\/modules\//
          File.delete(f) if File.symlink?(f)
        end
      end

      def link_support_dirs
        working_dir_links = Atmos.config['atmos.terraform.working_dir_links']
        working_dir_links ||= ['modules', 'templates']
        working_dir_links.each do |subdir|
          source = File.join(Atmos.config.root_dir, subdir)
          ln_sf(source, Atmos.config.tf_working_dir) if File.exist?(source)
        end
      end

      def link_recipes
        @recipes.each do |recipe|
          ln_sf(File.join(Atmos.config.root_dir, 'recipes', "#{recipe}.tf"), tf_recipes_dir)
        end
      end

      def pipe_stream(src, dest, &block)
         Thread.new do
           block_size = 1024
           begin
             while data = src.readpartial(block_size)
               data = block.call(data, flushing: false) if block
               dest.write(data)
             end
           rescue IOError, EOFError => e
             logger.log_exception(e, "Stream failure", level: :debug)
           rescue Exception => e
             logger.log_exception(e, "Stream failure")
           ensure
             begin
               if block
                 data = block.call('', flushing: true)
                 dest.write(data)
               end
               dest.flush
             rescue IOError, EOFError => e
               logger.log_exception(e, "Stream failure while flushing", level: :debug)
             rescue Exception => e
               logger.log_exception(e, "Stream failure while flushing")
             end
           end
         end
      end

    end

  end
end
