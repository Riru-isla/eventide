# Moves resources between planets, including between different players.
#
# Cargo leaves the sender's stores the moment a fleet is dispatched, so nobody can
# spend what is already in transit. It arrives in the recipient's stores when the fleet
# lands, capped by their storage — anything that will not fit stays in the hold and
# comes home rather than evaporating.
class Shipment
  class Error < StandardError; end

  def initialize(fleet)
    @fleet = fleet
    @empire = fleet.empire
  end

  # Takes the manifest out of the sender's stores. Raises unless they have it all.
  def self.load!(empire, manifest)
    manifest.each do |resource, amount|
      held = empire.public_send(resource)
      next if held >= amount

      raise Error, "only #{held} #{resource} available, #{amount} requested"
    end

    empire.update!(manifest.to_h { |resource, amount| [ resource, empire.public_send(resource) - amount ] })
  end

  # Unloads at the destination. Whatever does not fit stays aboard.
  def deliver!(recipient)
    remaining = @fleet.manifest.filter_map do |resource, amount|
      delivered = deposit(recipient, resource, amount)
      [ resource.to_s, amount - delivered ] if amount > delivered
    end.to_h

    @fleet.update!(cargo: remaining)
  end

  # Puts anything still aboard back into the sender's stores.
  def unload_home!
    @fleet.manifest.each { |resource, amount| deposit(@empire, resource, amount) }
    @fleet.update!(cargo: {})
  end

  private

  # Adds what fits under the empire's storage ceiling and returns how much landed. A
  # store already over capacity accepts nothing rather than being topped up further.
  def deposit(empire, resource, amount)
    capacity = empire.storage_capacity(resource)
    held = empire.public_send(resource)
    room = [ capacity - held, 0 ].max
    delivered = [ amount, room ].min

    empire.update!(resource => held + delivered) if delivered.positive?
    delivered
  end
end
