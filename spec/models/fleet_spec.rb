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
    it "calculates total attack power" do
      create(:ship_type, name: "Fighter", attack: 5)
      create(:ship_type, name: "Cruiser", attack: 20)
      fleet = build(:fleet, ships: { "Fighter" => 10, "Cruiser" => 1 })
      expect(fleet.power).to eq(70)
    end
  end
end
