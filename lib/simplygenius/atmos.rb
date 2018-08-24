require_relative 'atmos/version'
require 'active_support/core_ext/string'
require 'active_support/concern'

module SimplyGenius
  module Atmos
    mattr_accessor :config
  end
end

require_relative 'atmos/logging'
# SimplyGenius::Atmos::Logging.setup_logging(false, false, nil)

require_relative 'atmos/config'
