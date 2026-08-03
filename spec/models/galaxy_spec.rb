require 'rails_helper'

RSpec.describe Galaxy, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:sectors).dependent(:destroy) }
    it { is_expected.to have_many(:empires).dependent(:destroy) }
    it { is_expected.to have_many(:npc_factions).dependent(:destroy) }
    it { is_expected.to have_many(:fleets).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:width).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:height).is_greater_than(0) }
  end

  describe "status enum" do
    it "defaults to active" do
      galaxy = described_class.new
      expect(galaxy).to be_active
    end
  end

  describe "#center" do
    it "returns the integer center coordinate" do
      galaxy = build(:galaxy, width: 21, height: 21)
      expect(galaxy.center).to eq(x: 10, y: 10)
    end
  end
end
