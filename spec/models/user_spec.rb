require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:players).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
  end

  describe "authentication" do
    it "validates the correct password" do
      user = create(:user, password: "secret123")
      expect(user.valid_password?("secret123")).to be true
      expect(user.valid_password?("wrong")).to be false
    end
  end

  describe "administrators" do
    it "promotes the first account, since somebody has to create the first galaxy" do
      expect(create(:user)).to be_admin
    end

    it "leaves everyone who follows as an ordinary player" do
      create(:user)

      expect(create(:user)).not_to be_admin
    end
  end
end
