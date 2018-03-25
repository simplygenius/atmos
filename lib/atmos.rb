require 'atmos/version'

require 'atmos/logging'
Atmos::Logging.setup_logging(false, false, nil)

require 'atmos/config'
require 'active_support/core_ext/string'
require 'active_support/concern'

module Atmos
  mattr_accessor :config
end
