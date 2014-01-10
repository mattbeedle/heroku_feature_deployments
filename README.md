# HerokuFeatureDeployments

A very simple gem to automate deployment of the current git branch to Heroku,
configure DNS, notify PivotalTracker, etc. For more information, [see this blog
post](http://mattbeedle.name/posts/deploy-feature-branches-to-heroku-with-heroku-feature-deployments/)

## Installation

Add this line to your application's Gemfile:

    gem 'heroku_feature_deployments', group: :development

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install heroku_feature_deployments

## Configuration

```ruby
HerokuFeatureDeployments.configure do |config|
  # Heroku Configuration
  config.heroku_api_key = ENV['HEROKU_API_KEY']
  config.addons = [
    'memcachier:dev', 'sendgrid:starter', 'redistogo:nano'
  ] # List of all Heroku addons required
  config.env_vars = {
    S3_BUCKET_NAME: 'my-bucket',
    RACK_ENV: 'staging'
  }
  config.namespace = 'a-namespace' # Prefix all heroku app names with this, to
  avoid name collisions
  config.heroku_account_name = 'account-name' # The name of the heroku account
  you are using (https://github.com/ddollar/heroku-accounts)
  config.region = 'eu' # The region to deploy the app in (eu/us)
  config.collaborators = [
    'matt@gmail.com', 'another@gmail.com'
  ] # An array of collaborator email addresses

  # DNS configuration
  config.dnsimple_username = ENV['DNSIMPLE_USERNAME']
  config.dnsimple_api_key = ENV['DNSIMPLE_API_KEY']

  # GitHub Configuration
  config.github_token = ENV['GITHUB_TOKEN']
  config.github_repo = 'github project name' # The name of the github repo
  ('heroku_feature_deployments') for example

  # Pivotal Tracker Configuration
  config.pivotal_tracker_api_key = ENV['PIVOTAL_TRACKER_API_KEY']
  config.pivotal_tracker_project_id = ENV['PIVOTAL_TRACKER_PROJECT_ID']

  # Other
  config.logger = Rails.logger # Defaults to STDOUT
end if defined?(HerokuFeatureDeployments)
```

## Usage

First make sure that you are on the branch that you want to deploy
```bash
git checkout branch-name
```

Then deploy it!
```bash
rake hfd:deploy PIVOTAL_TICKET_ID=pivotal ticket ID here
```

Or alternatively, if this feature does not have a ticket in pivotal:
```bash
rake hfd:deploy
```

Later, when you are finished with it, then you can tear everything down with:
```bash
rake hfd:undeploy
```
Again, make sure that you are on the branch that you want to tear down!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
