module HerokuFeatureDeployments
  class PullRequestCreator

    def initialize(app_name, ticket_id, branch_name)
      @app_name = app_name
      @ticket_id = ticket_id
      @branch_name = branch_name
    end

    def create
      github = Github.new(
        oauth_token: HerokuFeatureDeployments.configuration.github_token
      )

      github.pull_requests.create(
        'geeland',
        HerokuFeatureDeployments.configuration.github_repo,
        title: title, body: body, head: @branch_name, base: 'master'
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
