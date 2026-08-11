require 'rails_helper'

RSpec.describe Player, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to have_many(:empires).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name scoped to galaxy" do
      galaxy = create(:galaxy)
      existing = create(:player, galaxy: galaxy, name: "Ada")
      new_player = build(:player, galaxy: galaxy, name: "Ada")
      expect(new_player).not_to be_valid
      expect(new_player.errors[:name]).to include("has already been taken")
    end
  end
end
