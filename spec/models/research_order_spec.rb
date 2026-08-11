require 'rails_helper'

RSpec.describe ResearchOrder, type: :model do
  let(:galaxy) { create(:galaxy, current_tick: 40) }
  let(:empire) { create(:empire, galaxy: galaxy) }

  def order(attrs = {})
    empire.create_research_order!(
      { kind: "energy_technology", target_level: 1, ticks_required: 10,
        started_at_tick: 40, completes_at_tick: 50 }.merge(attrs)
    )
  end

  describe "validations" do
    it "accepts a known technology" do
      expect(order).to be_persisted
    end

    it "rejects an unknown technology" do
      expect(empire.build_research_order(kind: "warp_theory", target_level: 1, ticks_required: 1)).not_to be_valid
    end

    it "rejects a non-positive target level" do
      expect(empire.build_research_order(kind: "energy_technology", target_level: 0, ticks_required: 1)).not_to be_valid
    end

    it "rejects a non-positive duration" do
      expect(empire.build_research_order(kind: "energy_technology", target_level: 1, ticks_required: 0)).not_to be_valid
    end
  end

  describe "progress" do
    it "counts down toward completion" do
      record = order

      expect(record.ticks_remaining(45)).to eq(5)
      expect(record.progress(45)).to eq(50.0)
    end

    it "never reports negative time or more than full progress" do
      record = order

      expect(record.ticks_remaining(999)).to eq(0)
      expect(record.progress(999)).to eq(100.0)
    end

    it "names the technology it is researching" do
      expect(order.name).to eq("Energy Technology")
    end
  end

  describe ".due" do
    it "finds orders that have come due" do
      record = order

      expect(empire.research_orders.due(49)).to be_empty
      expect(empire.research_orders.due(50)).to eq([ record ])
    end
  end
end
