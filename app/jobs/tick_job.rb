class TickJob < ApplicationJob
  queue_as :default

  def perform(galaxy_id)
    galaxy = Galaxy.find(galaxy_id)
    return unless galaxy.active?

    TickProcessor.new(galaxy).process

    # Schedule the next tick every minute for fast local play.
    # Tune this per game speed (e.g., 1 minute = 1 in-game tick).
    TickJob.set(wait: 1.minute).perform_later(galaxy_id)
  end
end
