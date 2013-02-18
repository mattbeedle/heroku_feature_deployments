require 'rubygems'
require 'heroku-api'
require 'dnsimple'
require 'github_api'
require 'pivotal-tracker'
require 'heroku_feature_deployments/configuration'
require 'heroku_feature_deployments/deployer'
require 'heroku_feature_deployments/pull_request_creator'
require 'heroku_feature_deployments/railtie' if defined?(Rails)
require 'heroku_feature_deployments/version'

module HerokuFeatureDeployments
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= HerokuFeatureDeployments::Configuration.new
    yield(configuration)
    return self.configuration
  end
end
