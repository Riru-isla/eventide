require 'rails_helper'

RSpec.describe Empire, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to belong_to(:home_sector).class_name("Sector").optional }
    it { is_expected.to have_many(:sectors).dependent(:nullify) }
    it { is_expected.to have_many(:fleets).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:role).in_array(Empire::ROLES) }
    it { is_expected.to validate_numericality_of(:metal).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:crystal).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:energy).is_greater_than_or_equal_to(0) }
  end

  describe "#name" do
    it "returns the player's name" do
      empire = build(:empire, player: build(:player, name: "Ada"))
      expect(empire.name).to eq("Ada's Empire")
    end
  end

  describe "#resource_bonus" do
    it "gives cultivators a crystal bonus" do
      empire = build(:empire, role: "cultivator")
      expect(empire.resource_bonus(:crystal)).to eq(1.5)
    end

    it "gives foundries a metal bonus" do
      empire = build(:empire, role: "foundry")
      expect(empire.resource_bonus(:metal)).to eq(1.5)
    end

    it "gives wardens an energy bonus" do
      empire = build(:empire, role: "warden")
      expect(empire.resource_bonus(:energy)).to eq(1.5)
    end

    it "returns 1.0 for non-matching resources" do
      empire = build(:empire, role: "cultivator")
      expect(empire.resource_bonus(:metal)).to eq(1.0)
    end
  end
end
