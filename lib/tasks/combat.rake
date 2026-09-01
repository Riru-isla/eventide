namespace :combat do
  desc %(Fight every hull against every other at equal cost: bin/rails "combat:matrix[budget,rounds]")
  task :matrix, [ :budget, :rounds ] => :environment do |_task, args|
    budget = (args[:budget] || Combat::Balance::DEFAULT_BUDGET).to_i
    rounds = (args[:rounds] || Combat::Resolver::ROUNDS).to_i

    puts "Equal investment of #{ActiveSupport::NumberHelper.number_to_delimited(budget)} " \
         "metal and crystal a side, #{rounds} rounds, attacker win rate."
    puts ""
    puts Combat::Balance.new(budget: budget, rounds: rounds).lines
  end
end
