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
