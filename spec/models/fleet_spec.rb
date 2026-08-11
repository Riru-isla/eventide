require 'rails_helper'

RSpec.describe Fleet, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:empire) }
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to belong_to(:origin_sector).class_name("Sector") }
    it { is_expected.to belong_to(:target_sector).class_name("Sector").optional }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:status).in_array(Fleet::STATUSES) }
  end

  describe "#total_ships" do
    it "sums ship counts" do
      fleet = build(:fleet, ships: { "Fighter" => 5, "Cruiser" => 2 })
      expect(fleet.total_ships).to eq(7)
    end
  end

  describe "#power" do
    before do
      create(:ship_type, name: "Fighter", attack: 5)
      create(:ship_type, name: "Cruiser", attack: 20)
    end

    it "calculates total attack power" do
      fleet = build(:fleet, ships: { "Fighter" => 10, "Cruiser" => 1 })
      expect(fleet.power).to eq(70)
    end

    it "ignores ship types it does not recognise" do
      fleet = build(:fleet, ships: { "Fighter" => 2, "Rowboat" => 100 })
      expect(fleet.power).to eq(10)
    end

    it "is raised by weapons research" do
      fleet = create(:fleet, ships: { "Fighter" => 10 })
      fleet.empire.technologies.create!(kind: "weapons_technology", level: 4) # +20%

      expect(fleet.reload.power).to eq(60)
      expect(fleet.base_power).to eq(50)
    end

    it "stacks laser research on top of weapons" do
      fleet = create(:fleet, ships: { "Fighter" => 10 })
      fleet.empire.technologies.create!(kind: "weapons_technology", level: 2) # +10%
      fleet.empire.technologies.create!(kind: "laser_technology", level: 5)   # +40%

      expect(fleet.reload.power).to eq(75)
    end
  end

  describe "#retreat!" do
    it "loses the whole fleet without armor research" do
      fleet = create(:fleet, ships: { "Fighter" => 10 }, status: "moving")

      expect(fleet.retreat!).to be false
    end

    it "brings a fraction home once armor is researched" do
      fleet = create(:fleet, ships: { "Fighter" => 10, "Cruiser" => 4 }, status: "moving")
      fleet.empire.technologies.create!(kind: "armor_technology", level: 5) # 50% survive

      expect(fleet.reload.retreat!).to be true
      expect(fleet.reload.ships).to eq("Fighter" => 5, "Cruiser" => 2)
      expect(fleet.status).to eq("orbiting")
      expect(fleet.target_sector).to be_nil
    end

    it "drops ship types too few to round up to one survivor" do
      fleet = create(:fleet, ships: { "Fighter" => 10, "Cruiser" => 1 }, status: "moving")
      fleet.empire.technologies.create!(kind: "armor_technology", level: 2) # 20% survive

      expect(fleet.reload.retreat!).to be true
      expect(fleet.reload.ships).to eq("Fighter" => 2)
    end
  end
end
