namespace :hfd do

  desc 'Deploy the current branch'
  task deploy: :environment do
    HerokuFeatureDeployments::Deployer.new.deploy(ENV['PIVOTAL_TICKET_ID'])
  end

  desc 'Undeploy the current branch'
  task undeploy: :environment do
    HerokuFeatureDeployments::Deployer.new.undeploy
  end
end
