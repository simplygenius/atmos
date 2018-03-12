require 'atmos/version'
require 'gem_logger'
require 'active_support/core_ext/string'
require 'active_support/concern'
require 'atmos/config'

module Atmos
  mattr_accessor :config
end
