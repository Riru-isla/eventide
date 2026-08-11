class PlanetStructuresController < ApplicationController
  class UpgradeError < StandardError; end

  def update
    planet = current_empire&.planet
    raise UpgradeError, "your empire has no planet" if planet.nil?

    structure = upgrade!(planet, params[:id])

    redirect_to planet_path(structure: structure.kind),
                notice: "#{structure.name} raised to level #{structure.level}."
  rescue UpgradeError, ActiveRecord::RecordInvalid => e
    redirect_to planet_path(structure: params[:id]), alert: "Could not upgrade: #{e.message}"
  end

  private

  # Upgrades are instant for now. Once game time is settled they become queued
  # builds, and this is where the queue entry gets created instead.
  def upgrade!(planet, kind)
    definition = Structure.find(kind)
    raise UpgradeError, "unknown structure" if definition.nil?

    ActiveRecord::Base.transaction do
      structure = planet.structures.find_or_create_by!(kind: kind) { |record| record.level = 0 }
      cost = structure.upgrade_cost

      unless affordable?(cost)
        raise UpgradeError, "#{structure.name} level #{structure.level + 1} needs " \
                            "#{cost[:metal]} metal and #{cost[:crystal]} crystal"
      end

      current_empire.update!(
        metal: current_empire.metal - cost[:metal],
        crystal: current_empire.crystal - cost[:crystal]
      )
      structure.update!(level: structure.level + 1)
      structure
    end
  end

  def affordable?(cost)
    current_empire.metal >= cost[:metal] && current_empire.crystal >= cost[:crystal]
  end
end
