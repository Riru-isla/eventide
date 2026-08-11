require 'rails_helper'

RSpec.describe ShipType, type: :model do
  describe ".find" do
    it "looks a hull up by key" do
      expect(described_class.find("battle_cruiser").name).to eq("Battle Cruiser")
    end

    it "returns nil for an unknown key" do
      expect(described_class.find("rowboat")).to be_nil
    end

    it "raises for an unknown key when using find!" do
      expect { described_class.find!("rowboat") }.to raise_error(KeyError)
    end
  end

  describe ".each_in" do
    it "pairs stored counts with their definitions" do
      pairs = described_class.each_in("light_fighter" => 3, "transport" => 1).to_a

      expect(pairs.map { |definition, count| [ definition.key, count ] })
        .to eq([ [ "light_fighter", 3 ], [ "transport", 1 ] ])
    end

    it "skips keys that are no longer in the catalogue" do
      pairs = described_class.each_in("light_fighter" => 2, "rowboat" => 99).to_a

      expect(pairs.map(&:first).map(&:key)).to eq([ "light_fighter" ])
    end
  end

  describe "#cost and #ticks_for" do
    it "scales cost with quantity" do
      expect(described_class.find("light_fighter").cost(4)).to eq(metal: 120, crystal: 40)
    end

    it "scales build time with quantity" do
      expect(described_class.find("transport").ticks_for(3)).to eq(6)
    end

    it "is shortened by a build speed multiplier" do
      hull = described_class.find("transport")

      expect(hull.ticks_for(3, speed_multiplier: 0.5)).to be < hull.ticks_for(3)
    end

    it "never takes less than a single tick" do
      expect(described_class.find("light_fighter").ticks_for(1, speed_multiplier: 0.0001)).to eq(1)
    end
  end

  describe "the roster" do
    it "names what a locked hull needs" do
      expect(described_class.find("battle_cruiser").requirement_labels)
        .to eq([ "Shipyard 6", "Laser Technology 1" ])
    end

    it "only depends on technologies that exist" do
      described_class.all.each do |hull|
        hull.requires.each_key do |key|
          expect(Technology.find(key)).to be_present, "#{hull.key} requires unknown #{key}"
        end
      end
    end

    it "has a hull buildable from a level 1 Shipyard with no research" do
      starters = described_class.all.select { |h| h.requires_shipyard <= 1 && h.requires.empty? }

      expect(starters.map(&:key)).to eq([ "light_fighter" ])
    end

    it "gives every hull a real attack, cargo and speed" do
      described_class.all.each do |hull|
        expect(hull.attack).to be_positive, "#{hull.key} has no attack"
        expect(hull.cargo).to be_positive, "#{hull.key} has no cargo"
        expect(hull.speed_factor).to be_positive, "#{hull.key} has no speed"
      end
    end
  end
end
