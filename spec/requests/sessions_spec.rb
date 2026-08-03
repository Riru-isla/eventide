require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Session Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:player) { galaxy.empires.first.player }

  describe "GET /session/new" do
    it "renders the login page" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log in")
    end
  end

  describe "POST /session" do
    it "logs in with valid credentials" do
      post session_path, params: { username: player.username, password: "eventide" }
      expect(response).to redirect_to(galaxy_path(galaxy))
      expect(session[:player_id]).to eq(player.id)
    end

    it "rejects invalid credentials" do
      post session_path, params: { username: player.username, password: "wrong" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:player_id]).to be_nil
    end
  end

  describe "DELETE /session" do
    it "logs out" do
      sign_in_player(player)
      delete session_path
      expect(response).to redirect_to(new_session_path)
      expect(session[:player_id]).to be_nil
    end
  end
end
