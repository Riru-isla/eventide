require 'rails_helper'

RSpec.describe EmpireTechnology, type: :model do
  let(:empire) { create(:empire) }

  describe "validations" do
    it "accepts a known technology" do
      expect(empire.technologies.new(kind: "weapons_technology", level: 1)).to be_valid
    end

    it "rejects an unknown technology" do
      expect(empire.technologies.new(kind: "warp_theory", level: 1)).not_to be_valid
    end

    it "rejects a negative level" do
      expect(empire.technologies.new(kind: "weapons_technology", level: -1)).not_to be_valid
    end

    it "allows a technology only once per empire" do
      empire.technologies.create!(kind: "weapons_technology", level: 1)

      expect(empire.technologies.new(kind: "weapons_technology", level: 2)).not_to be_valid
    end
  end

  it "delegates presentation to the catalogue" do
    technology = empire.technologies.create!(kind: "armor_technology", level: 2)

    expect(technology.name).to eq("Armor Technology")
    expect(technology.category).to eq("military")
    expect(technology.summary).to be_present
    expect(technology).to be_researched
  end

  describe ".researched" do
    it "excludes technologies still at level zero" do
      empire.technologies.create!(kind: "armor_technology", level: 2)
      empire.technologies.create!(kind: "weapons_technology", level: 0)

      expect(empire.technologies.researched.map(&:kind)).to eq([ "armor_technology" ])
    end
  end

  describe "empire bonuses" do
    it "reports zero for unresearched technologies" do
      expect(empire.technology_level("weapons_technology")).to eq(0)
      expect(empire.technology_bonus(:weapons)).to eq(0)
    end

    it "stacks every technology sharing an effect" do
      empire.technologies.create!(kind: "weapons_technology", level: 2)  # +10%
      empire.technologies.create!(kind: "laser_technology", level: 1)    # +8%

      expect(empire.reload.technology_bonus(:weapons)).to be_within(0.0001).of(0.18)
      expect(empire.attack_multiplier).to be_within(0.0001).of(1.18)
    end

    it "caps the armor survival fraction" do
      empire.technologies.create!(kind: "armor_technology", level: 50)

      expect(empire.reload.armor_survival).to eq(0.9)
    end
  end
end
