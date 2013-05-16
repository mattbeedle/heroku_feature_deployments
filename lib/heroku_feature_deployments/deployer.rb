module HerokuFeatureDeployments
  class Deployer

    def initialize(options = {})
      @branch_name = options[:branch_name] || get_branch_name
      @remote_name = options[:remote_name] || @branch_name.underscore
      @app_name = options[:app_name] || @branch_name.parameterize.
        gsub(/_/, '-')
      @full_app_name = "#{config.namespace}-#{@app_name}"
      @pivotal_tracker_project_id = options[:pivotal_tracker_project_id]

      DNSimple::Client.username = config.dnsimple_username
      DNSimple::Client.api_token = config.dnsimple_api_key

      # PivotalTracker::Client.token = config.pivotal_tracker_api_key
    end

    def deploy(pivotal_ticket_id)
      @pivotal_ticket_id = pivotal_ticket_id
      if app_exists?
        add_environment_variables
        add_collaborators
        push_code
        migrate_db
      else
        create_app
        add_collaborators
        add_addons
        add_to_dnsimple
        add_custom_domain
        add_environment_variables
        push_code
        create_db
        migrate_db
        seed_db
        # add_pivotal_comment if @pivotal_ticket_id
        create_pull_request
      end

      if config.domain
        run_command "open http://#{@app_name}.#{config.domain}"
      else
        run_command "open http://#{@full_app_name}.herokuapp.com"
      end
    end

    def undeploy
      delete_app
      remove_from_dnsimple
      remove_git_remote
    end

    private

    def add_collaborators
      config.logger.info 'Adding collaborators'
      config.collaborators.each do |collaborator|
        heroku.post_collaborator(@full_app_name, collaborator)
      end
    end

    def add_custom_domain
      config.logger.info 'Adding custom domain'
      heroku.post_domain(@full_app_name, "#{@app_name}.gohiring.com")
      heroku.post_domain(@full_app_name, "*.#{@app_name}.gohiring.com")
    end

    def create_pull_request
      config.logger.info "Creating Pull Request"
      run_command "git push origin #{@branch_name}"
      PullRequestCreator.new(@full_app_name, @pivotal_ticket_id, @branch_name).
        create
    rescue Github::Error::UnprocessableEntity
      config.logger.info 'Pull request already exists.'
    end

#     def add_pivotal_comment
#       PivotalTracker::Project.all
#       project = PivotalTracker::Project.find(config.pivotal_tracker_project_id)
#       project.stories.find(@pivotal_tracker_id).tap do |story|
#         story.notes.create(
#           text: "location: http://#{@app_name}.#{config.domain}"
#         )
#       end
#     end

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
      config.env_vars.merge!('SUBDOMAIN' => @app_name)
      heroku.put_config_vars(@full_app_name, config.env_vars)
    end

    def add_to_dnsimple
      config.logger.info "Adding records to DNSimple"
      domain = DNSimple::Domain.find(config.domain)
      DNSimple::Record.create(
        domain, @app_name, 'CNAME', 'proxy.herokuapp.com'
      )
      DNSimple::Record.create(
        domain, "*.#{@app_name}", 'CNAME', 'proxy.herokuapp.com'
      )
    end

    def remove_from_dnsimple
      config.logger.info "Removing records from DNSimple"
      domain = DNSimple::Domain.find(config.domain)
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
        run_command add_git_remote(response.body['git_url'])
      end
    end

    def add_git_remote(git_url)
      ['git remote add', @remote_name].tap do |command|
        if config.heroku_account_name
          command << git_url.gsub(/\.com/, ".#{config.heroku_account_name}")
        end
      end.join(' ')
    end

    def remove_git_remote
      ['git remote rm', @remote_name].join(' ')
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
