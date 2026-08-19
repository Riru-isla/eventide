namespace :admin do
  desc %(Grant administrator rights: bin/rails "admin:grant[ada]")
  task :grant, [ :username ] => :environment do |_task, args|
    AdminTask.set(args[:username], true)
  end

  desc %(Withdraw administrator rights: bin/rails "admin:revoke[ada]")
  task :revoke, [ :username ] => :environment do |_task, args|
    AdminTask.set(args[:username], false)
  end

  desc "List the accounts that can administer the server"
  task list: :environment do
    AdminTask.list
  end
end
