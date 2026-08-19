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
    it "never promotes an account on its own — admin comes from the console" do
      expect(create(:user)).not_to be_admin
      expect(create(:user)).not_to be_admin
    end

    it "lists the accounts that can administer the server" do
      admin = create(:user, admin: true)
      create(:user)

      expect(User.administrators).to contain_exactly(admin)
    end
  end
end
