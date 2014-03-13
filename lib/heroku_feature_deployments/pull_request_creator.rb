module HerokuFeatureDeployments
  class PullRequestCreator

    def initialize(app_name, ticket_id, branch_name)
      @app_name = app_name
      @ticket_id = ticket_id
      @branch_name = branch_name
    end

    def create
      client.create_pull_request(
        HerokuFeatureDeployments.configuration.github_repo,
        'master', @branch_name, title, body
      )
    rescue Octokit::UnprocessableEntity => e
      config.logger "An error occurred when creating the pull request: #{e.message}"
    end

    private

    def client
      @client ||= Octokit::Client.new(
        access_token: HerokuFeatureDeployments.configuration.github_token
      )
    end

    def title
      @app_name
    end

    def body
      @ticket_id
    end
  end
end
