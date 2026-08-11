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
      fleet = build(:fleet, ships: { "light_fighter" => 5, "medium_fighter" => 2 })
      expect(fleet.total_ships).to eq(7)
    end
  end

  describe "#power" do
    it "calculates total attack power" do
      fleet = build(:fleet, ships: { "light_fighter" => 10, "medium_fighter" => 1 })
      expect(fleet.power).to eq(65)
    end

    it "ignores ship types it does not recognise" do
      fleet = build(:fleet, ships: { "light_fighter" => 2, "rowboat" => 100 })
      expect(fleet.power).to eq(10)
    end

    it "is raised by weapons research" do
      fleet = create(:fleet, ships: { "light_fighter" => 10 })
      fleet.empire.technologies.create!(kind: "weapons_technology", level: 4) # +20%

      expect(fleet.reload.power).to eq(60)
      expect(fleet.base_power).to eq(50)
    end

    it "stacks laser research on top of weapons" do
      fleet = create(:fleet, ships: { "light_fighter" => 10 })
      fleet.empire.technologies.create!(kind: "weapons_technology", level: 2) # +10%
      fleet.empire.technologies.create!(kind: "laser_technology", level: 5)   # +40%

      expect(fleet.reload.power).to eq(75)
    end
  end

  describe "#cargo_capacity" do
    it "sums the hold of every hull" do
      fleet = build(:fleet, ships: { "light_fighter" => 2, "transport" => 1 })

      expect(fleet.cargo_capacity).to eq(540) # 2 x 20 + 500
    end

    it "ignores hulls no longer in the catalogue" do
      expect(build(:fleet, ships: { "rowboat" => 100 }).cargo_capacity).to eq(0)
    end
  end

  describe "#speed_factor" do
    it "moves at the pace of the slowest hull" do
      fleet = build(:fleet, ships: { "medium_fighter" => 5, "transport" => 1 })

      expect(fleet.speed_factor).to eq(1.4) # held back by the transport
    end

    it "is quick when only light hulls are aboard" do
      expect(build(:fleet, ships: { "medium_fighter" => 5 }).speed_factor).to eq(0.9)
    end

    it "falls back to normal speed for an unrecognised fleet" do
      expect(build(:fleet, ships: { "rowboat" => 1 }).speed_factor).to eq(1.0)
    end
  end

  describe "#retreat!" do
    it "loses the whole fleet without armor research" do
      fleet = create(:fleet, ships: { "light_fighter" => 10 }, status: "moving")

      expect(fleet.retreat!).to be false
    end

    it "brings a fraction home once armor is researched" do
      fleet = create(:fleet, ships: { "light_fighter" => 10, "medium_fighter" => 4 }, status: "moving")
      fleet.empire.technologies.create!(kind: "armor_technology", level: 5) # 50% survive

      expect(fleet.reload.retreat!).to be true
      expect(fleet.reload.ships).to eq("light_fighter" => 5, "medium_fighter" => 2)
      expect(fleet.status).to eq("orbiting")
      expect(fleet.target_sector).to be_nil
    end

    it "drops ship types too few to round up to one survivor" do
      fleet = create(:fleet, ships: { "light_fighter" => 10, "medium_fighter" => 1 }, status: "moving")
      fleet.empire.technologies.create!(kind: "armor_technology", level: 2) # 20% survive

      expect(fleet.reload.retreat!).to be true
      expect(fleet.reload.ships).to eq("light_fighter" => 2)
    end
  end
end
