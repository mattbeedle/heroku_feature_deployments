module HerokuFeatureDeployments
  class Configuration
    attr_accessor :heroku_api_key, :dnsimple_username, :dnsimple_api_key,
      :addons, :env_vars, :logger, :pivotal_tracker_api_key, :namespace,
      :github_token, :github_repo, :domain, :pivotal_tracker_project_id,
      :heroku_account_name, :collaborators, :region

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def collaborators
      @collaborators || []
    end
  end
end
