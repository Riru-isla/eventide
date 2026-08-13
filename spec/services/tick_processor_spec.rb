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

    it "trains crew once a Pilot Academy is built" do
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)
      empire.planet.structures.find_by(kind: "pilot_academy").update!(level: 2)

      expect { described_class.new(galaxy).process }.to change { empire.reload.crew }.by(4)
    end

    it "caps crew at the Crew Quarters ceiling" do
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)
      empire.planet.structures.find_by(kind: "pilot_academy").update!(level: 20) # 40 / tick
      empire.update!(crew: empire.storage_capacity(:crew) - 5)

      described_class.new(galaxy).process

      expect(empire.reload.crew).to eq(empire.storage_capacity(:crew))
    end

    it "still stops mining at the cap, not the overflow ceiling" do
      empire.home_sector.update!(metal_rate: 100, crystal_rate: 0)
      empire.planet.structures.find_by(kind: "solar_array").update!(level: 20)
      empire.update!(metal: empire.storage_capacity(:metal) - 10)

      described_class.new(galaxy).process

      expect(empire.reload.metal).to eq(empire.storage_capacity(:metal))
      expect(empire.metal).to be < empire.overflow_capacity(:metal)
    end

    it "does not accumulate energy" do
      expect { described_class.new(galaxy).process }.not_to change { empire.reload.energy }
    end

    describe "live updates" do
      it "tells connected clients to re-render once the tick has landed" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(galaxy)

        described_class.new(galaxy).process
      end

      it "broadcasts only after the work is committed" do
        allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to) do
          # A client refreshing on this signal must see the new tick, not the old one.
          expect(Galaxy.find(galaxy.id).current_tick).to eq(1)
        end

        described_class.new(galaxy).process
      end
    end

    it "resolves fleet arrivals and captures NPC sectors" do
      origin = empire.home_sector
      target = galaxy.sectors.npc.first
      target.update!(defense_strength: 10)

      fleet = galaxy.fleets.create!(
        empire: empire,
        origin_sector: origin,
        target_sector: target,
        arrival_tick: galaxy.current_tick,
        status: "moving",
        ships: { "light_fighter" => 10 }
      )

      described_class.new(galaxy).process

      target.reload
      expect(target.empire).to eq(empire)
      expect(target.npc_faction).to be_nil
      expect(fleet.reload.status).to eq("orbiting")
    end

    it "hauls plunder out of a captured sector, up to the fleet's cargo space" do
      target = galaxy.sectors.npc.first
      target.update!(defense_strength: 10, metal_rate: 20, crystal_rate: 20)

      galaxy.fleets.create!(
        empire: empire, origin_sector: empire.home_sector, target_sector: target,
        arrival_tick: galaxy.current_tick, status: "moving",
        ships: { "light_fighter" => 10, "transport" => 1 } # 700 cargo, haul capped at 400
      )

      expect { described_class.new(galaxy).process }.to change { empire.reload.metal }.by_at_least(200)
    end

    it "takes the ground but no spoils when a fleet has no cargo space" do
      target = galaxy.sectors.npc.first
      target.update!(defense_strength: 10, metal_rate: 20, crystal_rate: 20)

      fleet = galaxy.fleets.create!(
        empire: empire, origin_sector: empire.home_sector, target_sector: target,
        arrival_tick: galaxy.current_tick, status: "moving",
        ships: { "light_fighter" => 10 }
      )
      allow_any_instance_of(Fleet).to receive(:cargo_capacity).and_return(0)

      described_class.new(galaxy).process

      expect(target.reload.empire).to eq(empire)
      expect(fleet.reload.status).to eq("orbiting")
    end

    it "delivers finished hulls from the shipyard" do
      empire.update!(metal: 100_000, crystal: 100_000, crew: 1_000)
      order = empire.planet.shipyard.enqueue!("light_fighter", 3)
      galaxy.update!(current_tick: order.completes_at_tick)

      described_class.new(galaxy.reload).process

      garrison = empire.fleets.find_by(origin_sector: empire.home_sector, status: "orbiting")
      expect(garrison.ships["light_fighter"]).to eq(13) # 10 starting + 3 delivered
    end

    it "completes research that has come due" do
      empire.planet.structures.find_by(kind: "research_center").update!(level: 1)
      empire.update!(metal: 100_000, crystal: 100_000)
      order = empire.reload.research.start!("extraction_technology")
      galaxy.update!(current_tick: order.completes_at_tick)

      described_class.new(galaxy.reload).process

      expect(empire.reload.technology_level("extraction_technology")).to eq(1)
    end

    it "lets an armoured fleet retreat instead of being destroyed" do
      origin = empire.home_sector
      target = galaxy.sectors.npc.first
      target.update!(defense_strength: 10_000)
      empire.technologies.create!(kind: "armor_technology", level: 5)

      fleet = galaxy.fleets.create!(
        empire: empire,
        origin_sector: origin,
        target_sector: target,
        arrival_tick: galaxy.current_tick,
        status: "moving",
        ships: { "light_fighter" => 10 }
      )

      expect { described_class.new(galaxy).process }.not_to change { galaxy.fleets.count }

      fleet.reload
      expect(fleet.status).to eq("orbiting")
      expect(fleet.ships).to eq("light_fighter" => 5)
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
        ships: { "light_fighter" => 1 }
      )

      expect { described_class.new(galaxy).process }.to change { galaxy.fleets.count }.by(-1)
    end

    describe "shipments" do
      let!(:recipient) do
        other = create(:empire, galaxy: galaxy, player: create(:player, galaxy: galaxy),
                       metal: 0, crystal: 0)
        sector = galaxy.sectors.find_by(kind: "empty")
        sector.update!(empire: other)
        Planet.create!(empire: other, sector: sector, name: "Far World")
        other
      end

      def send_shipment(cargo: { "metal" => 300 }, ticks_out: 0)
        galaxy.fleets.create!(
          empire: empire, origin_sector: empire.home_sector,
          target_sector: recipient.planet.sector,
          arrival_tick: galaxy.current_tick + ticks_out,
          status: "moving", mission: "transport",
          ships: { "transport" => 2 }, cargo: cargo
        )
      end

      it "delivers into the recipient's stores on arrival" do
        send_shipment

        expect { described_class.new(galaxy).process }.to change { recipient.reload.metal }.by(300)
      end

      it "turns the fleet around rather than parking it there" do
        fleet = send_shipment

        described_class.new(galaxy).process

        expect(fleet.reload.status).to eq("returning")
        expect(fleet.arrival_tick).to be > galaxy.reload.current_tick
        expect(fleet.origin_sector).to eq(empire.home_sector)
      end

      it "leaves a shipment alone before it arrives" do
        send_shipment(ticks_out: 5)

        expect { described_class.new(galaxy).process }.not_to change { recipient.reload.metal }
      end

      it "folds the returning ships back into the home garrison" do
        # A second orbiting fleet at the same sector would strand its ships: the
        # dispatch form and shipyard only ever look at the first one.
        garrison = empire.fleets.find_by(origin_sector: empire.home_sector, status: "orbiting")
        before = garrison.ships["transport"]
        fleet = send_shipment
        described_class.new(galaxy).process
        galaxy.update!(current_tick: fleet.reload.arrival_tick)

        described_class.new(galaxy.reload).process

        expect(Fleet.exists?(fleet.id)).to be false
        expect(garrison.reload.ships["transport"]).to eq(before + 2)
        expect(empire.fleets.where(origin_sector: empire.home_sector, status: "orbiting").count).to eq(1)
      end

      it "becomes the garrison when nothing is orbiting at home" do
        empire.fleets.where(status: "orbiting").destroy_all
        fleet = send_shipment
        described_class.new(galaxy).process
        galaxy.update!(current_tick: fleet.reload.arrival_tick)

        described_class.new(galaxy.reload).process

        expect(fleet.reload.status).to eq("orbiting")
        expect(fleet.target_sector).to be_nil
        expect(fleet.cargo).to eq({})
      end

      it "lands a shipment even when the recipient is already at their mining cap" do
        recipient.update!(metal: recipient.storage_capacity(:metal))
        send_shipment

        expect { described_class.new(galaxy).process }.to change { recipient.reload.metal }.by(300)
      end

      it "carries an undeliverable load home instead of losing it" do
        recipient.update!(metal: recipient.overflow_capacity(:metal))
        fleet = send_shipment
        described_class.new(galaxy).process
        galaxy.update!(current_tick: fleet.reload.arrival_tick)

        expect { described_class.new(galaxy.reload).process }
          .to change { empire.reload.metal }.by_at_least(300)
      end

      it "returns a load sent to a sector nobody holds" do
        empty = galaxy.sectors.where(kind: "empty", empire_id: nil).first
        fleet = galaxy.fleets.create!(
          empire: empire, origin_sector: empire.home_sector, target_sector: empty,
          arrival_tick: galaxy.current_tick, status: "moving", mission: "transport",
          ships: { "transport" => 1 }, cargo: { "metal" => 100 }
        )

        described_class.new(galaxy).process

        expect(fleet.reload.status).to eq("returning")
        expect(fleet.manifest).to eq(metal: 100)
      end
    end

    it "skips a fleet under way with no destination left" do
      fleet = galaxy.fleets.create!(
        empire: empire, origin_sector: empire.home_sector,
        target_sector: galaxy.sectors.npc.first,
        arrival_tick: galaxy.current_tick, status: "moving", ships: { "light_fighter" => 1 }
      )
      fleet.update_column(:target_sector_id, nil)

      expect { described_class.new(galaxy).process }.not_to change { galaxy.fleets.count }
      expect(fleet.reload.status).to eq("moving")
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
        ships: { "light_fighter" => 5 }
      )

      described_class.new(galaxy).process

      fleet.reload
      expect(fleet.origin_sector).to eq(target)
      expect(fleet.target_sector).to be_nil
      expect(fleet.status).to eq("orbiting")
    end
  end
end
