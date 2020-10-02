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
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "test_construct"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"


  # core dependencies
  spec.add_dependency "activesupport", ">= 5.2.4.3"
  spec.add_dependency "gem_logger", "~> 0.3.0"
  spec.add_dependency "logging", "~> 2.2.2"
  spec.add_dependency "sigdump", "~> 0.2.4"
  spec.add_dependency "clamp", "~> 1.3.0"
  spec.add_dependency "thor", "~> 0.19.4"
  spec.add_dependency "highline", "~> 2.0.0"
  spec.add_dependency "rainbow", "~> 3.0.0"
  spec.add_dependency "git", "~> 1.5.0"
  spec.add_dependency "rubyzip", "~> 1.3.0"
  spec.add_dependency "hashie", "~> 3.6.0"
  spec.add_dependency "climate_control", "~> 0.2.0"
  spec.add_dependency "aws-sdk-core"
  spec.add_dependency "aws-sdk-iam"
  spec.add_dependency "aws-sdk-organizations"
  spec.add_dependency "aws-sdk-s3"
  spec.add_dependency "aws-sdk-ssm"
  spec.add_dependency "aws-sdk-ecr"
  spec.add_dependency "aws-sdk-ecs"
  spec.add_dependency "aws-sdk-cloudwatchlogs"
  spec.add_dependency "os", "~> 1.0.0"
  spec.add_dependency "rotp", "~> 3.3.1"
  spec.add_dependency "clipboard", "~> 1.1.2"
  spec.add_dependency "inifile", "~> 3.0.0"

  # plugin dependencies
  spec.add_dependency "deepsort"
  spec.add_dependency "diffy"

end
