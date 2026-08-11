require 'rails_helper'

RSpec.describe BuildOrder, type: :model do
  let(:galaxy) { create(:galaxy, current_tick: 50) }
  let(:planet) do
    Planet.create!(
      empire: create(:empire, galaxy: galaxy),
      sector: create(:sector, galaxy: galaxy),
      name: "World"
    )
  end

  def order(attrs = {})
    planet.build_orders.create!(
      { kind: "solar_array", target_level: 2, ticks_required: 10, position: 1 }.merge(attrs)
    )
  end

  describe "validations" do
    it "accepts a known structure" do
      expect(order).to be_persisted
    end

    it "rejects an unknown structure" do
      expect(planet.build_orders.new(kind: "orbital_casino", target_level: 1, ticks_required: 1)).not_to be_valid
    end

    it "rejects a non-positive target level" do
      expect(planet.build_orders.new(kind: "solar_array", target_level: 0, ticks_required: 1)).not_to be_valid
    end

    it "rejects a non-positive duration" do
      expect(planet.build_orders.new(kind: "solar_array", target_level: 1, ticks_required: 0)).not_to be_valid
    end
  end

  describe "progress" do
    it "is waiting until started" do
      record = order

      expect(record).not_to be_building
      expect(record.progress(50)).to eq(0.0)
      expect(record.ticks_remaining(50)).to eq(10)
    end

    it "counts down once started" do
      record = order
      record.start!(50)

      expect(record).to be_building
      expect(record.completes_at_tick).to eq(60)
      expect(record.ticks_remaining(53)).to eq(7)
      expect(record.progress(55)).to eq(50.0)
    end

    it "never reports negative time or more than full progress" do
      record = order
      record.start!(50)

      expect(record.ticks_remaining(999)).to eq(0)
      expect(record.progress(999)).to eq(100.0)
    end

    it "names the structure it is building" do
      expect(order.name).to eq("Solar Array")
    end
  end

  describe "scopes" do
    it "separates building from waiting orders" do
      waiting = order(position: 2)
      active = order(kind: "refinery", position: 1)
      active.start!(50)

      expect(planet.build_orders.building).to eq([ active ])
      expect(planet.build_orders.waiting).to eq([ waiting ])
    end

    it "finds orders due at a tick" do
      record = order
      record.start!(50)

      expect(planet.build_orders.due(59)).to be_empty
      expect(planet.build_orders.due(60)).to eq([ record ])
    end
  end
end
