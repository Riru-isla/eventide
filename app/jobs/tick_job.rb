class TickJob < ApplicationJob
  queue_as :default

  # Called with no argument by the Solid Queue schedule in config/recurring.yml,
  # which advances every active galaxy once a minute. Pass a galaxy id to tick a
  # single galaxy by hand.
  #
  # The job deliberately does not reschedule itself: a self-rescheduling chain
  # stops silently the first time a run fails or the queue is reset, and a long
  # running season would then quietly stop ticking.
  def perform(galaxy_id = nil)
    scope = galaxy_id ? Galaxy.where(id: galaxy_id) : Galaxy.all

    scope.active.find_each do |galaxy|
      TickProcessor.new(galaxy).process
    end
  end
end
