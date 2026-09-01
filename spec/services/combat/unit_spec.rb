require 'rails_helper'

RSpec.describe Combat::Unit, type: :service do
  subject(:corvette) do
    described_class.new(key: :corvette, name: "Corvette", category: "ship",
                        shield: 10, armour: 20, hull: 40,
                        damage: { shield: 50, armour: 40, hull: 30 })
  end

  let(:turret) do
    described_class.new(key: :light_turret, name: "Light Turret", category: "ground_defence",
                        shield: 100, armour: 100, hull: 200,
                        damage: { shield: 60, armour: 60, hull: 60 })
  end

  it "reports what a weapon does to each layer" do
    expect(corvette.damage_against(:shield)).to eq(50)
    expect(corvette.damage_against(:hull)).to eq(30)
  end

  it "adds its layers up" do
    expect(corvette.total_integrity).to eq(70)
  end

  it "knows a ship from something bolted to the ground" do
    expect(corvette).to be_ship
    expect(corvette).to be_mobile
    expect(turret).not_to be_ship
    # Immobile things only ever fight where they stand.
    expect(turret).not_to be_mobile
  end

  it "treats defences as the same shape as ships, so the resolver need not tell them apart" do
    expect(turret).to be_a(described_class)
    expect(Combat::CATEGORIES).to include(turret.category)
  end
end
