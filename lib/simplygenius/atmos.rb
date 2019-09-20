require_relative 'atmos/version'

# FIXME: Force active support json to prevent some weird errors.  We don't really rely
# on it, but guessing some gem does and causes a breakage when calling to_json in
# ui.rb when running its spec:
# NameError: uninitialized constant ActiveSupport::JSON Did you mean?  JSON
#
require 'active_support/json'
require 'active_support/core_ext/object/json'

require 'active_support/core_ext/string'
require 'active_support/concern'

module SimplyGenius
  module Atmos
    mattr_accessor :config
  end
end

require_relative 'atmos/logging'
require_relative 'atmos/config'
