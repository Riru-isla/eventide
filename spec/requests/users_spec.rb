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

  describe "GET /users/new" do
    it "renders the signup page" do
      get new_user_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Join Eventide")
    end
  end

  describe "POST /users" do
    it "creates a player, empire, and logs them in" do
      expect {
        post users_path, params: {
          player: {
            name: "Ben",
            username: "ben",
            password: "secret123",
            password_confirmation: "secret123"
          },
          empire: { role: "warden" }
        }
      }.to change(Player, :count).by(1)
        .and change(Empire, :count).by(1)

      player = Player.last
      expect(session[:player_id]).to eq(player.id)
      expect(session[:empire_id]).to eq(player.empires.first.id)
      expect(response).to redirect_to(galaxy_path(galaxy))
    end

    it "rejects mismatched passwords" do
      expect {
        post users_path, params: {
          player: {
            name: "Ben",
            username: "ben",
            password: "secret123",
            password_confirmation: "wrong"
          },
          empire: { role: "warden" }
        }
      }.not_to change(Player, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
