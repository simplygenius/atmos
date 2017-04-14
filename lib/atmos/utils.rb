module Atmos
  module Utils

    include GemLogger::LoggerSupport

    # Opens the file for writing by root
    def sudo_open(path, mode, perms=0755, &block)
      open("|sudo tee #{path} > /dev/null", perms, &block)
    end

    extend self

  end
end
