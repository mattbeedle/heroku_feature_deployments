# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'heroku_feature_deployments/version'

Gem::Specification.new do |gem|
  gem.name          = "heroku_feature_deployments"
  gem.version       = HerokuFeatureDeployments::VERSION
  gem.authors       = ["Matt Beedle"]
  gem.email         = ["mattbeedle@googlemail.com"]
  gem.description   = %q{Gem to deploy the current git branch to a new app on heroku}
  gem.summary       = %q{Gem to deploy the current git branch to a new app on heroku}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency('heroku-api')
  gem.add_runtime_dependency('dnsimple-ruby')
  gem.add_runtime_dependency('octokit')
  gem.add_runtime_dependency('pivotal-tracker')

  gem.add_development_dependency('rspec')
  gem.add_development_dependency('vcr')
end
