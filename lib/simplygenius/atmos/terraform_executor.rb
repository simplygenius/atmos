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

      def initialize(process_env: ENV, working_group: 'default')
        @process_env = process_env
        @working_group = working_group
        @working_dir = Atmos.config.tf_working_dir(@working_group)
        @recipes = Atmos.config["recipes.#{@working_group}"]
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

        # lets tempfiles created by subprocesses be easily found by users
        env['TMPDIR'] = Atmos.config.tmp_dir

        # Lets terraform communicate back to atmos, e.g. for UI notifications
        ipc = Ipc.new(Atmos.config.tmp_dir)

        IO.pipe do |stdout, stdout_writer|
          IO.pipe do |stderr, stderr_writer|

            stdout_writer.sync = stderr_writer.sync = true

            stdout_filters = Atmos.config.plugin_manager.output_filters(:stdout, {process_env: @process_env, working_group: @working_group})
            stderr_filters = Atmos.config.plugin_manager.output_filters(:stderr, {process_env: @process_env, working_group: @working_group})

            stdout_thr = pipe_stream(stdout, output_io.nil? ? $stdout : output_io, &stdout_filters.filter_block)
            stderr_thr = pipe_stream(stderr, output_io.nil? ? $stderr : output_io, &stderr_filters.filter_block)

            ipc.listen do |sock_path|

              if Atmos.config['ipc.disable']
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
        link_shared_plugin_dir
        link_support_dirs
        link_recipes
        write_atmos_vars
        setup_backend(skip_backend)
      end

      def setup_backend(skip_backend=false)
        backend_file = File.join(tf_recipes_dir, 'atmos-backend.tf.json')
        backend_config = (Atmos.config["backend"] || {}).clone

        if backend_config.present? && ! skip_backend
          logger.debug("Writing out terraform state backend config")

          # Use a different state file per group
          if @working_group
            backend_config['key'] = "#{@working_group}-#{backend_config['key']}"
          end

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

      # terraform currently (v0.11.7) doesn't handle maps with nested maps or
      # lists well, so flatten them - nested maps get expanded into the top level
      # one, with their keys being appended with underscores, and lists get
      # joined with "," so we end up with a single hash with homogenous types
      #
      def homogenize_for_terraform(obj, prefix="")
        if obj.is_a? Hash
          result = {}
          obj.each do |k, v|
            ho = homogenize_for_terraform(v, "#{prefix}#{k}_")
            if ho.is_a? Hash
              result = result.merge(ho)
            else
              result["#{prefix}#{k}"] = ho
            end
          end
          return result
        elsif obj.is_a? Array
          result = []
          obj.each do |o|
            ho = homogenize_for_terraform(o, prefix)
            if ho.is_a? Hash
              result << ho.collect {|k, v| "#{k}=#{v}"}.join(";")
            else
              result << ho
            end
          end
          return result.join(",")
        else
          return obj
        end
      end

      def tf_recipes_dir
        @tf_recipes_dir ||= begin
          dir = File.join(@working_dir, 'recipes')
          logger.debug("Tf recipes dir: #{dir}")
          mkdir_p(dir)
          dir
        end
      end

      def write_atmos_vars
        File.open(File.join(tf_recipes_dir, 'atmos.auto.tfvars.json'), 'w') do |f|
          # A mapping in the auto vars file is ignored if a variable declaration doesn't exist for it in a tf file.  Thus,
          # as a convenience to allow everything from atmos to be referenceable, we put everything from the atmos_config
          # in a homogenized hash named atmos_config which is declared by the atmos scaffolding.  For variables which are
          # declared, we also merge in atmos config with only the values homogenized (vs the entire map) so that hash
          # variables if declared in terraform can be managed from yml, set here and accessed from terraform
          #
          atmos_config = homogenize_for_terraform(Atmos.config.to_h)
          var_hash = {
              atmos_env: Atmos.config.atmos_env,
              all_env_names: Atmos.config.all_env_names,
              account_ids: Atmos.config.account_hash,
              atmos_config: atmos_config
          }
          var_hash = var_hash.merge(Atmos.config.to_h)
          f.puts(JSON.pretty_generate(var_hash))
        end
      end

      def secrets_env
        # NOTE use an auto-deleting temp file if passing secrets through env ends
        # up being problematic
        # TODO fix the need for CC - TE calls for secrets which needs auth in
        # ENV, so kinda clunk to have to do both CC and pass the env in
        ClimateControl.modify(@process_env) do
          secrets = Atmos.config.provider.secret_manager.to_h
          env_secrets = Hash[secrets.collect { |k, v| ["TF_VAR_#{k}", v] }]
          return env_secrets
        end
      end

      def clean_links
        Find.find(@working_dir) do |f|
          Find.prune if f =~ /\/.terraform\/modules\//
          File.delete(f) if File.symlink?(f)
        end
      end

      def link_support_dirs
        ['modules', 'templates'].each do |subdir|
          ln_sf(File.join(Atmos.config.root_dir, subdir), @working_dir)
        end
      end

      def link_shared_plugin_dir
        if ! Atmos.config["terraform.disable_shared_plugins"]
          shared_plugins_dir = File.join(Atmos.config.tmp_root, "terraform_plugins")
          mkdir_p(shared_plugins_dir)
          terraform_state_dir = File.join(tf_recipes_dir, '.terraform')
          mkdir_p(terraform_state_dir)
          terraform_plugins_dir = File.join(terraform_state_dir, 'plugins')
          ln_sf(shared_plugins_dir, terraform_plugins_dir)
        end
      end

      def link_recipes
        @recipes.each do |recipe|
          ln_sf(File.join(Atmos.config.root_dir, 'recipes', "#{recipe}.tf"), tf_recipes_dir)
        end
      end

      def pipe_stream(src, dest)
         Thread.new do
           block_size = 1024
           begin
             while data = src.readpartial(block_size)
               data = yield data if block_given?
               dest.write(data)
             end
           rescue IOError, EOFError => e
             logger.log_exception(e, "Stream failure", level: :debug)
           rescue Exception => e
             logger.log_exception(e, "Stream failure")
           end
         end
      end

    end

  end
end
