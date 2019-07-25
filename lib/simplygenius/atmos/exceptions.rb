require_relative '../atmos'
require 'clamp'

module SimplyGenius
  module Atmos

    module Exceptions
      class UsageError < Clamp::UsageError

      end
      class ConfigInterpolationError < ::ScriptError

      end
    end

  end
end
