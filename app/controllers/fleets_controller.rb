class FleetsController < ApplicationController
  class DispatchError < StandardError; end

  before_action :load_empire

  def index
    @fleets = fleets_for_display
    @garrison = garrison_at_home
    @destinations = destination_planets
  end

  def create
    fleet = dispatch_fleet

    flash.now[:notice] = if fleet.transport?
      "#{fleet.total_ships} ships away to #{fleet.target_system.coordinate}, " \
      "carrying #{manifest_summary(fleet)}. Back in #{fleet.arrival_tick - @galaxy.current_tick} ticks."
    else
      "#{fleet.total_ships} ships dispatched to #{fleet.target_system.coordinate}."
    end

    respond_with_fleets
  rescue DispatchError, Shipment::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    flash.now[:alert] = "Could not dispatch: #{e.message}"
    respond_with_fleets
  end

  private

  def load_empire
    @empire = current_empire
    @galaxy = @empire&.galaxy

    redirect_to galaxy_path(Galaxy.first), alert: "Your empire has no planet yet." if @empire&.planet.nil?
  end

  def fleets_for_display
    @empire.fleets.includes(:origin_system, target_system: { empire: :player }).order(:arrival_tick, :id)
  end

  # Ships can only be sent from the planet, which is where the shipyard delivers them.
  def garrison_at_home
    @empire.fleets.find_by(origin_system: @empire.planet.system, status: "orbiting")
  end

  # Every planet in the galaxy is a valid destination — this is a cooperative game, so
  # shipping to another commander is the point rather than an exploit.
  def destination_planets
    Planet.includes(:system, empire: :player)
          .where(empire: @galaxy.empires)
          .reject { |planet| planet.id == @empire.planet.id }
  end

  def dispatch_fleet
    ships = requested_ships
    raise DispatchError, "select at least one ship" if ships.empty?

    target = @galaxy.systems.find(params[:fleet][:target_system_id])
    origin = requested_origin

    ActiveRecord::Base.transaction do
      garrison = @empire.fleets.find_by(origin_system: origin, status: "orbiting")
      raise DispatchError, "no ships are stationed at #{origin.coordinate}" if garrison.nil?

      detach!(garrison, ships)

      fleet = @galaxy.fleets.new(
        empire: @empire, origin_system: origin, target_system: target,
        status: "moving", mission: mission, ships: ships, cargo: {}
      )
      fleet.cargo = load_cargo(fleet) if fleet.transport?
      fleet.arrival_tick = @galaxy.current_tick + fleet.travel_ticks_between(origin, target)
      fleet.save!
      fleet
    end
  end

  # Cargo leaves the sender's stores now, not on arrival, so nothing can be spent twice
  # while it is in transit.
  def load_cargo(fleet)
    manifest = requested_cargo
    raise DispatchError, "a transport needs something to carry" if manifest.empty?

    hold = fleet.cargo_capacity
    total = manifest.values.sum
    raise DispatchError, "#{total} exceeds the fleet's hold of #{hold}" if total > hold

    Shipment.load!(@empire, manifest)
    manifest.transform_keys(&:to_s)
  end

  # Subtracts the requested ships from the garrison, or raises if it cannot cover
  # them. A garrison left with no ships is disbanded rather than kept as an empty
  # fleet, since Fleet requires ships to be present.
  def detach!(garrison, ships)
    remaining = garrison.ships.dup

    ships.each do |key, count|
      available = remaining[key].to_i

      if available < count
        # Players see hull names, never catalogue keys.
        label = ShipType.find(key)&.name || key
        raise DispatchError, "only #{available} #{label} stationed at #{garrison.origin_system.coordinate}"
      end

      remaining[key] = available - count
    end

    remaining.reject! { |_, count| count.zero? }
    remaining.empty? ? garrison.destroy! : garrison.update!(ships: remaining)
  end

  # Fleets usually leave from the planet, but one that captured a system sits there and
  # can push on from it.
  def requested_origin
    given = params[:fleet][:origin_system_id]
    return @empire.planet.system if given.blank?

    @empire.systems.find(given)
  end

  def mission
    Fleet::MISSIONS.include?(params[:fleet][:mission]) ? params[:fleet][:mission] : "attack"
  end

  def requested_ships
    raw = params.require(:fleet)[:ships]
    return {} if raw.blank?

    raw.to_unsafe_h.transform_values(&:to_i).reject { |_, count| count <= 0 }
  end

  def requested_cargo
    raw = params.require(:fleet)[:cargo]
    return {} if raw.blank?

    raw.to_unsafe_h.symbolize_keys
       .slice(*PlanetEconomy::STORED)
       .transform_values(&:to_i)
       .reject { |_, amount| amount <= 0 }
  end

  def manifest_summary(fleet)
    fleet.manifest.map { |resource, amount| "#{number_with_delimiter(amount)} #{resource}" }.to_sentence
  end

  def number_with_delimiter(value) = ActiveSupport::NumberHelper.number_to_delimited(value)

  def respond_with_fleets
    @empire = current_empire.reload
    @fleets = fleets_for_display
    @garrison = garrison_at_home
    @destinations = destination_planets

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace("hud", partial: "shared/hud", locals: { empire: @empire }),
          turbo_stream.update("planet-main", partial: "fleets/board",
                              locals: { empire: @empire, fleets: @fleets,
                                        garrison: @garrison, destinations: @destinations })
        ]
      end

      format.html do
        flash.keep
        redirect_to fleets_path
      end
    end
  end
end
