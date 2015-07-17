module HerokuFeatureDeployments
  class Deployer

    attr :pivotal_ticket_id

    def initialize(options = {})
      @branch_name = options[:branch_name] || get_branch_name
      @remote_name = options[:remote_name] || @branch_name.underscore
      @app_name = options[:app_name] || @branch_name.parameterize.
        gsub(/_/, '-')
      @full_app_name = "#{config.namespace}-#{@app_name}"

      DNSimple::Client.username = config.dnsimple_username
      DNSimple::Client.api_token = config.dnsimple_api_key

      PivotalTracker::Client.token = config.pivotal_tracker_api_key
      PivotalTracker::Client.use_ssl = true if config.pivotal_use_ssl
    end

    # options
    #   :pivotal_ticket_id - if nil, ticket id will be fetched from branch
    #     name. 
    def deploy(options = {})
      @pivotal_ticket_id = options[:pivotal_ticket_id]
      if app_exists?
        add_environment_variables
        add_collaborators
        push_code
        migrate_db
        add_pivotal_new_version_comment if @pivotal_ticket_id
      else
        create_app
        add_features
        add_collaborators
        add_addons
        add_to_dnsimple
        add_custom_domain
        add_environment_variables
        push_code
        create_db
        add_pivotal_comment if @pivotal_ticket_id
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

    def add_features
      config.logger.info 'Adding features'
      # heroku.post_feature('user-env-compile', @full_app_name)
    end

    def wait_for_process_to_finish(command)
      config.logger.info "waiting for #{command} to finish"

      while true
        break unless running_process_names.
          any? { |n| n.match(/#{Regexp.escape(command)}/i) }
        print '.'
        sleep 5
      end
      puts
    end

    def running_process_names
      heroku.get_ps(@full_app_name).body.map { |i| i['command'] }
    end

    def add_collaborators
      config.logger.info 'Adding collaborators'
      config.collaborators.each do |collaborator|
        heroku.post_collaborator(@full_app_name, collaborator)
      end
    end

    def add_custom_domain
      config.logger.info 'Adding custom domain'
      heroku.post_domain(@full_app_name, "#{@app_name}.#{config.domain}")
      heroku.post_domain(@full_app_name, "*.#{@app_name}.#{config.domain}")
    end

    def create_pull_request
      config.logger.info "Creating Pull Request"
      run_command "git push origin #{@branch_name}"
      PullRequestCreator.new(@full_app_name, @pivotal_ticket_id, @branch_name).
        create
    end

    def add_pivotal_comment
      if find_pivotal_story
        find_pivotal_story.notes.create(
          text: "Test at: http://#{@app_name}.#{config.domain}"
        )
        deliver_pivotal_story
      end
    end

    def add_pivotal_new_version_comment
      if find_pivotal_story
        find_pivotal_story.notes.create(
          text: "A new version has just been deployed"
        )
        deliver_pivotal_story
      end
    end

    def deliver_pivotal_story
      find_pivotal_story.update current_state: 'delivered'
    end

    def find_pivotal_story
      PivotalTracker::Project.all
      project = PivotalTracker::Project.find(config.pivotal_tracker_project_id)
      project.stories.find(@pivotal_ticket_id)
    end

    def get_branch_name
      `git rev-parse --abbrev-ref HEAD`.strip
    end

    # Default to ticket id from branch name in format:
    # "48586573-pg-tags" -> "48586573".
    def pivotal_ticket_id(branch_name = get_branch_name)
      @pivotal_ticket_id ||= ((branch_name =~ /^(\d+)/ rescue false) ? $1 : nil)
    end

    def create_db
      config.logger.info "Creating and migrating the database"
      heroku.post_ps(@full_app_name, 'rake db:create db:migrate')
      wait_for_process_to_finish 'rake db:create db:migrate'
      config.logger.info 'Seeding the database'
      heroku.post_ps(@full_app_name, 'rake db:seed')
      wait_for_process_to_finish 'rake db:seed'
    end

    def migrate_db
      config.logger.info "Migrating database"
      heroku.post_ps(@full_app_name, 'rake db:migrate')
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
      config.env_vars.merge!('APP_SUBDOMAIN' => @app_name)
      heroku.put_config_vars(@full_app_name, config.env_vars)
    end

    def add_to_dnsimple
      config.logger.info "Adding records to DNSimple"
      domain = DNSimple::Domain.find(config.domain)
      DNSimple::Record.create(
        domain, @app_name, 'CNAME', "#{@full_app_name}.herokuapp.com"
      )
      DNSimple::Record.create(
        domain, "*.#{@app_name}", 'CNAME', "#{@full_app_name}.herokuapp.com"
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
      heroku.post_app(name: @full_app_name, region: config.region || 'us').tap do |response|
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

    def wait_for_process_to_finish(command)
      config.logger.info "waiting for #{command} to finish"

      while true
        break unless running_process_names.
          any? { |n| n.match(/#{Regexp.escape(command)}/i) }
        print '.'
        sleep 5
      end
      puts
    end
  end
end
