class FleetsController < ApplicationController
  class DispatchError < StandardError; end

  def create
    @galaxy = Galaxy.find(params[:galaxy_id])
    origin = current_empire.sectors.find(params[:fleet][:origin_sector_id])
    target = @galaxy.sectors.find(params[:fleet][:target_sector_id])

    fleet = dispatch_fleet(origin, target)

    redirect_to galaxy_path(@galaxy),
                notice: "Dispatched #{fleet.total_ships} ships to #{target.coordinate}."
  rescue DispatchError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to galaxy_path(@galaxy), alert: "Could not dispatch fleet: #{e.message}"
  end

  private

  # Ships come out of the garrison orbiting the origin sector. Without this the
  # dispatch form would conjure ships out of nothing, and any player could take the
  # core on the first tick.
  #
  # Named dispatch_fleet, not dispatch: ActionController defines a public #dispatch
  # and redefining it privately breaks request handling.
  def dispatch_fleet(origin, target)
    ships = requested_ships
    raise DispatchError, "select at least one ship" if ships.empty?

    ActiveRecord::Base.transaction do
      garrison = current_empire.fleets.find_by(origin_sector: origin, status: "orbiting")
      raise DispatchError, "no ships are stationed at #{origin.coordinate}" if garrison.nil?

      detach!(garrison, ships)

      @galaxy.fleets.create!(
        empire: current_empire,
        origin_sector: origin,
        target_sector: target,
        arrival_tick: @galaxy.current_tick + travel_ticks(origin, target),
        status: "moving",
        ships: ships
      )
    end
  end

  # Subtracts the requested ships from the garrison, or raises if it cannot cover
  # them. A garrison left with no ships is disbanded rather than kept as an empty
  # fleet, since Fleet requires ships to be present.
  def detach!(garrison, ships)
    remaining = garrison.ships.dup

    ships.each do |name, count|
      available = remaining[name].to_i
      raise DispatchError, "only #{available} #{name} stationed at #{garrison.origin_sector.coordinate}" if available < count

      remaining[name] = available - count
    end

    remaining.reject! { |_, count| count.zero? }
    remaining.empty? ? garrison.destroy! : garrison.update!(ships: remaining)
  end

  def travel_ticks(origin, target)
    [ origin.distance_to(target.x, target.y).ceil, 1 ].max
  end

  def requested_ships
    raw = params.require(:fleet)[:ships]
    return {} if raw.blank?

    raw.to_unsafe_h.transform_values(&:to_i).reject { |_, count| count <= 0 }
  end
end
