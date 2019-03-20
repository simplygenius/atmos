# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'simplygenius/atmos/version'

Gem::Specification.new do |spec|
  spec.name          = "simplygenius-atmos"
  spec.version       = SimplyGenius::Atmos::VERSION
  spec.authors       = ["Matt Conway"]
  spec.email         = ["matt@simplygenius.com"]

  spec.summary       = %q{Atmos provides a terraform scaffold for creating cloud system architectures}
  spec.description   = %q{Atmos provides a terraform scaffold for creating cloud system architectures}
  spec.homepage      = "https://github.com/simplygenius/atmos"
  spec.license       = "Apache-2.0"

  spec.files = Dir['*.md', 'LICENSE', 'exe/**/*', 'lib/**/*', 'templates/**/*']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "simplecov", "~> 0.10"
  spec.add_development_dependency "coveralls", "~> 0.8"
  spec.add_development_dependency "test_construct", "~> 2.0.1"
  spec.add_development_dependency "vcr", "~> 4.0.0"
  spec.add_development_dependency "webmock", "~> 3.3.0"
  spec.add_development_dependency "pry", "~> 0.11.3"
  spec.add_development_dependency "pry-byebug", "~> 3.6.0"


  # core dependencies
  spec.add_dependency "activesupport", "~> 5.2.1"
  spec.add_dependency "gem_logger", "~> 0.3.0"
  spec.add_dependency "logging", "~> 2.2.2"
  spec.add_dependency "sigdump", "~> 0.2.4"
  spec.add_dependency "clamp", "~> 1.3.0"
  spec.add_dependency "thor", "~> 0.19.4"
  spec.add_dependency "highline", "~> 2.0.0"
  spec.add_dependency "rainbow", "~> 3.0.0"
  spec.add_dependency "git", "~> 1.5.0"
  spec.add_dependency "rubyzip", "~> 1.2.2"
  spec.add_dependency "hashie", "~> 3.6.0"
  spec.add_dependency "climate_control", "~> 0.2.0"
  spec.add_dependency "aws-sdk-core", "~> 3.28.0"
  spec.add_dependency "aws-sdk-iam", "~> 1.8.0"
  spec.add_dependency "aws-sdk-organizations", "~> 1.13.0"
  spec.add_dependency "aws-sdk-s3", "~> 1.20.0"
  spec.add_dependency "aws-sdk-ecr", "~> 1.6.0"
  spec.add_dependency "aws-sdk-ecs", "~> 1.20.0"
  spec.add_dependency "os", "~> 1.0.0"
  spec.add_dependency "rotp", "~> 3.3.1"
  spec.add_dependency "clipboard", "~> 1.1.2"

end
