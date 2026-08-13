# Builds a new session's galaxy in the background.
#
# A large galaxy is 160,000 sectors. Even bulk inserted that is far too slow to do
# inside a request, and it only ever happens once per session, so it can take as long as
# it needs to.
class GalaxyGenerationJob < ApplicationJob
  queue_as :default

  def perform(name:, size: "small", player_configs: [])
    GalaxyGenerator.new(name: name, size: size, player_configs: player_configs).generate
  end
end
