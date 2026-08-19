require 'rails_helper'

RSpec.describe Shipment, type: :service do
  let(:galaxy) { create(:galaxy) }
  let(:sender) { create(:empire, galaxy: galaxy, metal: 5_000, crystal: 5_000, crew: 50) }
  let(:recipient) { create(:empire, galaxy: galaxy, metal: 0, crystal: 0, crew: 0) }
  let(:origin) { create(:system, galaxy: galaxy) }

  def planet_for(empire)
    planet = Planet.create!(empire: empire, system: create(:system, galaxy: galaxy), name: "World")
    Structure::STARTING_LEVELS.each { |kind, level| planet.structures.create!(kind: kind, level: level) }
    planet
  end

  def fleet_with(cargo, ships: { "transport" => 2 })
    create(:fleet, empire: sender, galaxy: galaxy, origin_system: origin, ships: ships, cargo: cargo)
  end

  describe ".load!" do
    it "takes the manifest out of the sender's stores" do
      expect { described_class.load!(sender, metal: 300, crystal: 100) }
        .to change { sender.reload.metal }.by(-300)
        .and change { sender.reload.crystal }.by(-100)
    end

    it "refuses what the sender does not have" do
      expect { described_class.load!(sender, metal: 99_999) }
        .to raise_error(described_class::Error, /only 5000 metal available/)
    end

    it "takes nothing when any part of the manifest is short" do
      expect { described_class.load!(sender, metal: 100, crew: 999) rescue nil }
        .not_to change { sender.reload.metal }
    end
  end

  describe "#deliver!" do
    before { planet_for(recipient) }

    it "puts the cargo into the recipient's stores" do
      fleet = fleet_with({ "metal" => 400, "crystal" => 200 })

      expect { described_class.new(fleet).deliver!(recipient) }
        .to change { recipient.reload.metal }.by(400)
        .and change { recipient.reload.crystal }.by(200)
    end

    it "empties the hold once everything lands" do
      fleet = fleet_with({ "metal" => 400 })

      described_class.new(fleet).deliver!(recipient)

      expect(fleet.reload.cargo).to eq({})
      expect(fleet).not_to be_carrying
    end

    it "lands in full even when the recipient is already at their mining cap" do
      # A gift should not bounce because the recipient happens to be topped up.
      capacity = recipient.storage_capacity(:metal)
      recipient.update!(metal: capacity)
      fleet = fleet_with({ "metal" => 400 })

      described_class.new(fleet).deliver!(recipient)

      expect(recipient.reload.metal).to eq(capacity + 400)
      expect(fleet.reload.cargo).to eq({})
    end

    it "delivers only what fits under the overflow ceiling" do
      ceiling = recipient.overflow_capacity(:metal)
      recipient.update!(metal: ceiling - 50)
      fleet = fleet_with({ "metal" => 400 })

      described_class.new(fleet).deliver!(recipient)

      expect(recipient.reload.metal).to eq(ceiling)
      expect(fleet.reload.manifest).to eq(metal: 350)
    end

    it "keeps the whole load aboard when the recipient is at the overflow ceiling" do
      recipient.update!(metal: recipient.overflow_capacity(:metal))
      fleet = fleet_with({ "metal" => 400 })

      described_class.new(fleet).deliver!(recipient)

      expect(fleet.reload.manifest).to eq(metal: 400)
    end
  end

  describe "#unload_home!" do
    it "returns undelivered cargo to the sender" do
      fleet = fleet_with({ "metal" => 250 })

      expect { described_class.new(fleet).unload_home! }
        .to change { sender.reload.metal }.by(250)

      expect(fleet.reload.cargo).to eq({})
    end
  end
end
