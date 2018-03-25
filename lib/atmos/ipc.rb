require 'atmos'
require 'fileutils'
require 'hashie'

module Atmos
  class Ipc
    include GemLogger::LoggerSupport

    def initialize(sock_dir=Dir.tmpdir)
      @sock_dir = sock_dir
    end

    def listen(&block)
      raise "Already listening" if @server

      begin
        @socket_path = File.join(@sock_dir, 'atmos-ipc')
        FileUtils.rm_f(@socket_path)
        @server = UNIXServer.open(@socket_path)
      rescue ArgumentError => e
        if e.message =~ /too long unix socket path/ && @sock_dir != Dir.tmpdir
          logger.warn("Using tmp for ipc socket as path too long: #{@socket_path}")
          @sock_dir = Dir.tmpdir
          retry
        end
      end

      begin
        thread = Thread.new { run }
        block.call(@socket_path)
      ensure
        @server.close
        FileUtils.rm_f(@socket_path)
        @server = nil
      end
    end

    def generate_client_script
      script_file = File.join(@sock_dir, 'atmos_ipc.rb')
      File.write(script_file, <<~EOF
        #!/usr/bin/env ruby
        require 'socket'
        UNIXSocket.open('#{@socket_path}') {|c| c.puts(ARGV[0] || $stdin.read); puts c.gets }
      EOF
      )
      FileUtils.chmod('+x', script_file)
      return script_file
    end

    private

    def run
      logger.debug("Starting ipc thread")
      begin
        while @server && sock = @server.accept
          logger.debug("An ipc client connected")
          line = sock.gets
          logger.debug("Got ipc message: #{line.inspect}")
          response = {}

          begin
            msg = JSON.parse(line)
            msg = Hashie.symbolize_keys(msg)

            # enabled by default if enabled is not set (e.g. from provisioner local-exec)
            enabled = msg[:enabled].nil? ? true : ["true", "1"].include?(msg[:enabled].to_s)

            if enabled
              logger.debug("Dispatching IPC action")
              response = dispatch(msg)
            else
              response[:message] = "IPC action is not enabled"
              logger.debug(response[:error])
            end
          rescue => e
            logger.log_exception(e, "Failed to parse ipc message")
            response[:error] = "Failed to parse ipc message #{e.message}"
          end

          respond(sock, response)
          sock.close
        end
      rescue IOError, EOFError, Errno::EBADF
        nil
      rescue Exception => e
        logger.log_exception(e, "Ipc failure")
      end
    end

    def close
      @server.close if @server rescue nil
    end

    def load_action(name)
      action = nil
      logger.debug("Loading ipc action: #{name}")
      begin
        require "atmos/ipc_actions/#{name}"
        action = "Atmos::IpcActions::#{name.camelize}".constantize
        logger.debug("Loaded ipc action #{name}")
      rescue LoadError, NameError => e
        logger.log_exception(e, "Failed to load ipc action")
      end
      return action
    end

    def dispatch(msg)
      response = {}
      action = load_action(msg[:action])
      if action.nil?
        response[:error] = "Unsupported ipc action: #{msg.to_hash.inspect}"
        logger.warn(response[:error])
      else
        begin
          response = action.new().execute(**msg)
        rescue => e
          response[:error] = "Failure while executing ipc action: #{e.message}"
          logger.log_exception(e, "Failure while executing ipc action")
        end
      end
      return response
    end

    def respond(sock, response)
      msg = JSON.generate(response)
      logger.debug("Sending ipc response: #{msg.inspect}")
      sock.puts(msg)
      sock.flush
    end

  end
end
