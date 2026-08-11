require 'rails_helper'

RSpec.describe "Users", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "User Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  describe "GET /users/sign_up" do
    it "renders the signup page" do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Join Eventide")
    end
  end

  describe "POST /users" do
    it "creates a user, player, empire, and logs them in" do
      expect {
        post user_registration_path, params: {
          user: {
            username: "ben",
            password: "secret123",
            password_confirmation: "secret123"
          },
          empire: { role: "warden" }
        }
      }.to change(User, :count).by(1)
        .and change(Player, :count).by(1)
        .and change(Empire, :count).by(1)

      user = User.last
      expect(user.players.count).to eq(1)
      expect(response).to redirect_to(planet_path)
    end

    it "rejects mismatched passwords" do
      expect {
        post user_registration_path, params: {
          user: {
            username: "ben",
            password: "secret123",
            password_confirmation: "wrong"
          },
          empire: { role: "warden" }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
