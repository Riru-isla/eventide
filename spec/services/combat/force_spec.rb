require 'rails_helper'

RSpec.describe Combat::Force, type: :service do
  def unit(key)
    Combat::Unit.new(key: key, name: key.to_s, category: "ship", signature: 1,
                     shield: 0, armour: 0, hull: 10, damage: { shield: 5, armour: 5, hull: 5 })
  end

  let(:corvette) { unit(:corvette) }
  let(:frigate) { unit(:frigate) }

  describe ".of" do
    it "builds a stack per kind brought" do
      force = described_class.of("Fleet", { corvette => 10, frigate => 4 })

      expect(force.name).to eq("Fleet")
      expect(force.alive).to eq(14)
      expect(force.stacks.size).to eq(2)
    end

    it "ignores a kind that brought nobody" do
      force = described_class.of("Fleet", { corvette => 10, frigate => 0 })

      expect(force.stacks.size).to eq(1)
      expect(force.survivors).to eq({ corvette: 10 })
    end
  end

  describe "shooting" do
    it "fires once per unit still standing" do
      force = described_class.of("Fleet", { corvette => 3, frigate => 2 })
      shots = []
      force.each_shot { |damage| shots << damage }

      expect(shots.size).to eq(5)
    end
  end

  describe "counting" do
    let(:force) { described_class.of("Fleet", { corvette => 3 }) }

    it "reports nothing lost before a shot lands" do
      expect(force).to be_any
      expect(force.losses).to be_zero
      expect(force.casualties).to be_empty
    end

    it "reports casualties once units go down" do
      killing = { shield: 100, armour: 100, hull: 100 }
      2.times { force.stacks.first.take(killing, Random.new(1)) }

      expect(force.losses).to eq(2)
      expect(force.casualties).to eq({ corvette: 2 })
      expect(force.survivors).to eq({ corvette: 1 })
    end

    it "is spent once nothing is left" do
      killing = { shield: 100, armour: 100, hull: 100 }
      3.times { force.stacks.first.take(killing, Random.new(1)) }

      expect(force).not_to be_any
      expect(force.standing).to be_empty
      expect(force.survivors).to be_empty
    end

    it "brings shields back across every stack" do
      expect { force.regenerate! }.not_to raise_error
    end
  end
end
