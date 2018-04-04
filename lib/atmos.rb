require_relative 'atmos/version'

require_relative 'atmos/logging'
Atmos::Logging.setup_logging(false, false, nil)

require_relative 'atmos/config'
require 'active_support/core_ext/string'
require 'active_support/concern'

module Atmos
  mattr_accessor :config
end
