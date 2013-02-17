module HerokuFeatureDeployments
  class Railtie < Rails::Railtie
    railtie_name :heroku_feature_deployments

    rake_tasks do
      load 'tasks/heroku_feature_deployments.rake'
    end
  end
end
