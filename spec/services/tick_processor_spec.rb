require 'rails_helper'

RSpec.describe TickProcessor, type: :service do
  let(:galaxy) do
    GalaxyGenerator.new(
      name: "Tick Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }

  describe "#process" do
    it "increments the galaxy tick" do
      expect { described_class.new(galaxy).process }.to change { galaxy.reload.current_tick }.by(1)
    end

    it "collects resources for empires" do
      starting_metal = empire.metal
      described_class.new(galaxy).process
      expect(empire.reload.metal).to be > starting_metal
    end

    it "applies role bonuses to resource income" do
      empire.update!(role: "foundry")
      base_sector = empire.home_sector
      base_sector.update!(metal_rate: 100, crystal_rate: 0, energy_rate: 0)

      described_class.new(galaxy).process
      expect(empire.reload.metal).to eq(500 + 150)
    end

    it "takes planet income from structure levels" do
      empire.home_sector.update!(metal_rate: 100, crystal_rate: 0)
      empire.planet.structures.find_by(kind: "metal_extractor").update!(level: 3)
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)

      described_class.new(galaxy).process

      # base 100 x level 3 = 300, plus 50% foundry doctrine
      expect(empire.reload.metal).to eq(500 + 450)
    end

    it "throttles planet income while the planet is in energy deficit" do
      empire.home_sector.update!(metal_rate: 100, crystal_rate: 0)
      empire.planet.structures.find_by(kind: "metal_extractor").update!(level: 3)
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 0)

      described_class.new(galaxy).process

      expect(empire.reload.metal).to eq(500 + (450 * PlanetEconomy::THROTTLE).round)
    end

    it "still collects flat rates from sectors without a planet" do
      empire.home_sector.update!(metal_rate: 0, crystal_rate: 0)
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)
      captured = galaxy.sectors.find_by(kind: "empty")
      captured.update!(empire: empire, metal_rate: 40, crystal_rate: 0)

      described_class.new(galaxy).process

      expect(empire.reload.metal).to eq(500 + 60) # 40 with the foundry bonus
    end

    it "stops collecting once storage is full" do
      empire.home_sector.update!(metal_rate: 100, crystal_rate: 0)
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)
      empire.update!(metal: empire.storage_capacity(:metal) - 10)

      described_class.new(galaxy).process

      expect(empire.reload.metal).to eq(empire.storage_capacity(:metal))
    end

    it "leaves a stockpile that is already over capacity alone" do
      over = empire.storage_capacity(:metal) * 2
      empire.update!(metal: over)

      described_class.new(galaxy).process

      expect(empire.reload.metal).to eq(over)
    end

    it "collects more once a silo raises the cap" do
      empire.home_sector.update!(metal_rate: 100, crystal_rate: 0)
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)
      empire.planet.structures.find_by(kind: "metal_silo").update!(level: 4)
      empire.update!(metal: Structure::BASE_STORAGE)

      described_class.new(galaxy).process

      expect(empire.reload.metal).to be > Structure::BASE_STORAGE
    end

    it "does not accumulate energy" do
      expect { described_class.new(galaxy).process }.not_to change { empire.reload.energy }
    end

    it "resolves fleet arrivals and captures NPC sectors" do
      origin = empire.home_sector
      target = galaxy.sectors.npc.first
      target.update!(defense_strength: 10)

      create(:ship_type, name: "Fighter", attack: 5)
      fleet = galaxy.fleets.create!(
        empire: empire,
        origin_sector: origin,
        target_sector: target,
        arrival_tick: galaxy.current_tick,
        status: "moving",
        ships: { "Fighter" => 10 }
      )

      described_class.new(galaxy).process

      target.reload
      expect(target.empire).to eq(empire)
      expect(target.npc_faction).to be_nil
      expect(fleet.reload.status).to eq("orbiting")
    end

    it "destroys fleets that lose combat" do
      origin = empire.home_sector
      target = galaxy.sectors.npc.first
      target.update!(defense_strength: 10_000)

      fleet = galaxy.fleets.create!(
        empire: empire,
        origin_sector: origin,
        target_sector: target,
        arrival_tick: galaxy.current_tick,
        status: "moving",
        ships: { "Fighter" => 1 }
      )

      expect { described_class.new(galaxy).process }.to change { galaxy.fleets.count }.by(-1)
    end

    it "moves fleets to empty sectors without combat" do
      origin = empire.home_sector
      target = galaxy.sectors.find_by(kind: "empty")

      fleet = galaxy.fleets.create!(
        empire: empire,
        origin_sector: origin,
        target_sector: target,
        arrival_tick: galaxy.current_tick,
        status: "moving",
        ships: { "Fighter" => 5 }
      )

      described_class.new(galaxy).process

      fleet.reload
      expect(fleet.origin_sector).to eq(target)
      expect(fleet.target_sector).to be_nil
      expect(fleet.status).to eq("orbiting")
    end
  end
end
