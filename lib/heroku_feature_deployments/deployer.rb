module HerokuFeatureDeployments
  class Deployer

    def initialize(pivotal_ticket_id, options = {})
      @branch_name = options[:branch_name] || get_branch_name
      @remote_name = options[:remote_name] || @branch_name.underscore
      @app_name = options[:app_name] || @branch_name.parameterize.
        gsub(/_/, '-')
      @full_app_name = "#{config.namespace}-#{@app_name}"
      @pivotal_ticket_id = pivotal_ticket_id
      @pivotal_tracker_project_id = options[:pivotal_tracker_project_id]

      DNSimple::Client.username = config.dnsimple_username
      DNSimple::Client.api_token = config.dnsimple_api_key

      PivotalTracker::Client.token = config.pivotal_tracker_api_key
    end

    def deploy
      if app_exists?
        add_environment_variables
        push_code
        migrate_db
      else
        create_app
        add_addons
        add_to_dnsimple
        add_environment_variables
        push_code
        create_db
        migrate_db
        seed_db
        add_pivotal_comment if @pivotal_ticket_id
        create_pull_request
      end

      open_app
    end

    def undeploy
      delete_app
      remove_from_dnsimple
    end

    private

    def create_pull_request
      github = Github.new oauth_token: config.github_token
      github.pull_requests.create 'mattbeedle', config.github_repo,
        title: @full_app_name, body: @pivotal_ticket_id, head: @branch_name,
        base: 'master'
    end

    def open_app
      sleep 60
      run_command "heroku open #{@full_app_name}"
    end

    def add_pivotal_comment
      project = PivotalTracker::Project.find(config.pivotal_tracker_project_id)
      project.stories.find(@pivotal_tracker_id).tap do |story|
        story.notes.create(text: "location: http://#{@app_name}#{@domain}")
      end
    end

    def get_branch_name
      `git branch`.split("\n").select {|s| s =~ /\*/ }.first.gsub(/\*/, '').
        strip
    end

    def create_db
      config.logger.info "Creating database"
      heroku.post_ps(@full_app_name, 'rake db:create')
    end

    def migrate_db
      config.logger.info "Migrating database"
      heroku.post_ps(@full_app_name, 'rake db:migrate')
    end

    def seed_db
      config.logger.info "Seeding database"
      heroku.post_ps(@full_app_name, 'rake db:seed')
    end

    def push_code
      run_command "git push #{@remote_name} #{@branch_name}:master"
    end

    def app_exists?
      @app_exists ||= heroku.get_apps.body.any? do |a|
        a['name'] == @full_app_name
      end
    end

    def add_environment_variables
      config.logger.info "Adding environment variables"
      heroku.put_config_vars(@full_app_name, config.env_vars)
    end

    def add_to_dnsimple
      config.logger.info "Adding records to DNSimple"
      domain = DNSimple::Domain.find('gohiring.com')
      DNSimple::Record.create(
        domain, @app_name, 'CNAME', 'proxy.herokuapp.com'
      )
      DNSimple::Record.create(
        domain, "*.#{@app_name}", 'CNAME', 'proxy.herokuapp.com'
      )
    end

    def remove_from_dnsimple
      config.logger.info "Removing records from DNSimple"
      domain = DNSimple::Domain.find('gohiring.com')
      DNSimple::Record.all(domain).each do |record|
        record.destroy if %W(#{@app_name} *.#{@app_name}).include?(record.name)
      end
    end

    def migrate_database
      heroku.post_ps(@full_app_name, 'rake db:migrate --trace')
    end

    def create_app
      config.logger.info "Creating App #{@full_app_name}"
      heroku.post_app(name: @full_app_name).tap do |response|
        run_command(
          "git remote add #{@remote_name} #{response.body['git_url']}"
        )
      end
    end

    def delete_app
      config.logger.info "Deleting App #{@full_app_name}"
      heroku.delete_app(@full_app_name)
      run_command "git remote rm #{@remote_name}"
    end

    def add_addons
      config.logger.info "Adding addons"
      config.addons.each do |addon|
        config.logger.info "Adding #{addon}"
        heroku.post_addon(@full_app_name, addon)
      end
    end

    def heroku
      @heroku ||= Heroku::API.new(api_key: config.heroku_api_key)
    end

    def config
      @config ||= HerokuFeatureDeployments.configuration
    end

    def run_command(command)
      config.logger.info "Running command: #{command}"
      system command
    end
  end
end
