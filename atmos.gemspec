# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'atmos/version'

Gem::Specification.new do |spec|
  spec.name          = "atmos"
  spec.version       = Atmos::VERSION
  spec.authors       = ["Matt Conway"]
  spec.email         = ["matt@simplygenius.com"]

  spec.summary       = %q{Atmos provides a terraform scaffold for creating cloud system architectures}
  spec.description   = %q{Atmos provides a terraform scaffold for creating cloud system architectures}
  spec.homepage      = "https://github.com/simplygenius/atmos"
  spec.license       = "Apache-2.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "test_construct", "~> 2.0.1"
  spec.add_development_dependency "vcr", "~> 4.0.0"
  spec.add_development_dependency "webmock", "~> 3.3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"


  # core dependencies
  spec.add_dependency "activesupport"
  spec.add_dependency "gem_logger"
  spec.add_dependency "logging"
  spec.add_dependency "sigdump"
  spec.add_dependency "clamp"
  spec.add_dependency "thor"
  spec.add_dependency "highline"
  spec.add_dependency "rainbow"
  spec.add_dependency "git"
  spec.add_dependency "rubyzip"
  spec.add_dependency "hashie"
  spec.add_dependency "climate_control"
  spec.add_dependency "aws-sdk"
  spec.add_dependency "os"

end
