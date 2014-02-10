# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails_daemon/version'

Gem::Specification.new do |spec|
  spec.name          = "rails_daemon"
  spec.version       = RailsDaemon::VERSION
  spec.authors       = ["Snap CI"]
  spec.email         = ["snap-ci@thoughtworks.com"]
  spec.summary       = %q{Daemonize and fork Rails processes}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_dependency "rake"
  spec.add_dependency "rails"
end
