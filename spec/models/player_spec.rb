require 'rails_helper'

RSpec.describe Player, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:empires).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username) }
  end

  describe "authentication" do
    it "authenticates with the correct password" do
      player = create(:player, password: "secret123")
      expect(player.authenticate("secret123")).to eq(player)
      expect(player.authenticate("wrong")).to be_falsey
    end
  end
end
