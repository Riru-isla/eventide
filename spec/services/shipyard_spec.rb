require 'rails_helper'

RSpec.describe Shipyard, type: :service do
  let(:galaxy) { create(:galaxy, current_tick: 300) }
  let(:empire) { create(:empire, galaxy: galaxy, metal: 500_000, crystal: 500_000, crew: 5_000) }
  let(:sector) { create(:sector, galaxy: galaxy) }
  let!(:planet) { Planet.create!(empire: empire, sector: sector, name: "World") }

  before do
    Structure::STARTING_LEVELS.each { |kind, level| planet.structures.create!(kind: kind, level: level) }
  end

  def set_shipyard(level)
    planet.structures.find_by(kind: "shipyard").update!(level: level)
  end

  def yard = Planet.find(planet.id).shipyard

  describe "gating" do
    it "is not operational without a Shipyard" do
      set_shipyard(0)

      expect(yard).not_to be_operational
    end

    it "allows the starter hull at Shipyard 1" do
      expect(yard).to be_available(ShipType.find("light_fighter"))
    end

    it "locks a hull when the Shipyard is too small" do
      expect(yard.unmet_requirements(ShipType.find("medium_fighter")))
        .to include("Shipyard 2")
    end

    it "locks a hull when the technology is missing" do
      set_shipyard(6)

      expect(yard.unmet_requirements(ShipType.find("battle_cruiser")))
        .to eq([ "Laser Technology 1" ])
    end

    it "unlocks once the Shipyard and research are in place" do
      set_shipyard(6)
      empire.technologies.create!(kind: "laser_technology", level: 1)

      expect(yard).to be_available(ShipType.find("battle_cruiser"))
    end
  end

  describe "#enqueue!" do
    it "charges the empire and queues the batch" do
      cost = ShipType.find("light_fighter").cost(5)

      expect { yard.enqueue!("light_fighter", 5) }
        .to change { empire.reload.metal }.by(-cost[:metal])
        .and change(ShipOrder, :count).by(1)
    end

    it "starts the first batch immediately" do
      order = yard.enqueue!("light_fighter", 3)

      expect(order.completes_at_tick).to eq(300 + order.ticks_required)
    end

    it "leaves a second batch waiting" do
      yard.enqueue!("light_fighter", 1)
      second = yard.enqueue!("light_fighter", 1)

      expect(second.completes_at_tick).to be_nil
    end

    it "refuses a locked hull and names what is missing" do
      expect { yard.enqueue!("battle_cruiser", 1) }
        .to raise_error(described_class::Error, /Shipyard 6/)
    end

    it "refuses an unknown hull" do
      expect { yard.enqueue!("rowboat", 1) }.to raise_error(described_class::Error, /unknown ship/)
    end

    it "refuses a quantity below one" do
      expect { yard.enqueue!("light_fighter", 0) }.to raise_error(described_class::Error, /at least one/)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { yard.enqueue!("light_fighter", 1) }.to raise_error(described_class::Error, /needs/)
    end

    it "leaves no order behind when it cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { yard.enqueue!("light_fighter", 1) rescue nil }.not_to change(ShipOrder, :count)
    end

    it "spends crew as well as metal and crystal" do
      cost = ShipType.find("light_fighter").cost(5)

      expect { yard.enqueue!("light_fighter", 5) }.to change { empire.reload.crew }.by(-cost[:crew])
    end

    it "refuses a batch the empire has no crew for" do
      empire.update!(crew: 0)

      expect { yard.enqueue!("light_fighter", 1) }.to raise_error(described_class::Error, /crew/)
    end

    it "charges the heavier hulls far more crew" do
      set_shipyard(6)
      empire.technologies.create!(kind: "laser_technology", level: 1)

      expect(ShipType.find("battle_cruiser").crew_cost).to be > ShipType.find("light_fighter").crew_cost * 10
    end

    it "builds faster with a Robotics Bay" do
      slow = yard.enqueue!("light_fighter", 10).ticks_required
      ShipOrder.delete_all
      planet.structures.find_by(kind: "robotics_bay").update!(level: 8)

      expect(yard.enqueue!("light_fighter", 10).ticks_required).to be < slow
    end
  end

  describe "#advance!" do
    it "leaves a batch alone before it is due" do
      yard.enqueue!("light_fighter", 2)

      yard.advance!

      expect(ShipOrder.count).to eq(1)
    end

    it "delivers finished hulls into the orbiting garrison" do
      garrison = galaxy.fleets.create!(empire: empire, origin_sector: sector,
                                       status: "orbiting", ships: { "light_fighter" => 4 })
      order = yard.enqueue!("light_fighter", 6)
      galaxy.update!(current_tick: order.completes_at_tick)

      yard.advance!

      expect(garrison.reload.ships).to eq("light_fighter" => 10)
      expect(ShipOrder.count).to eq(0)
    end

    it "starts a new garrison when the planet has none" do
      order = yard.enqueue!("light_fighter", 2)
      galaxy.update!(current_tick: order.completes_at_tick)

      expect { yard.advance! }.to change { empire.fleets.count }.by(1)
      expect(empire.fleets.first.ships).to eq("light_fighter" => 2)
    end

    it "chains the next batch from when the previous finished" do
      first = yard.enqueue!("light_fighter", 1)
      second = yard.enqueue!("light_fighter", 1)
      galaxy.update!(current_tick: first.completes_at_tick)

      yard.advance!

      expect(second.reload.completes_at_tick).to eq(first.completes_at_tick + second.ticks_required)
    end

    it "clears the whole queue when a long gap has passed" do
      first = yard.enqueue!("light_fighter", 1)
      yard.enqueue!("light_fighter", 1)
      galaxy.update!(current_tick: first.completes_at_tick + 10_000)

      yard.advance!

      expect(ShipOrder.count).to eq(0)
      expect(empire.fleets.first.ships).to eq("light_fighter" => 2)
    end

    it "does nothing on an empty yard" do
      expect { yard.advance! }.not_to raise_error
    end
  end

  describe "#current" do
    it "reports the batch under way" do
      yard.enqueue!("light_fighter", 1)

      expect(yard.current.kind).to eq("light_fighter")
    end

    it "is nil when the yard is idle" do
      expect(yard.current).to be_nil
    end
  end
end
