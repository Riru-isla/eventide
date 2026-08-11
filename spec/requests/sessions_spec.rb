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

  let(:user) { galaxy.players.first.user }

  describe "GET /users/sign_in" do
    it "renders the login page" do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log in")
    end
  end

  describe "POST /users/sign_in" do
    it "logs in with valid credentials" do
      post user_session_path, params: { user: { username: user.username, password: "eventide" } }
      expect(response).to redirect_to(galaxy_path(galaxy))
    end

    it "rejects invalid credentials" do
      post user_session_path, params: { user: { username: user.username, password: "wrong" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /users/sign_out" do
    it "logs out" do
      sign_in user
      delete destroy_user_session_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
