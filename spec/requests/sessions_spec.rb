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

  let(:empire) { galaxy.empires.first }

  describe "GET /session/new" do
    it "renders the login page" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Choose your empire")
    end
  end

  describe "POST /session" do
    it "logs in with valid credentials" do
      post session_path, params: { galaxy_id: galaxy.id, empire_id: empire.id, password: "eventide" }
      expect(response).to redirect_to(galaxy_path(galaxy))
      expect(session[:empire_id]).to eq(empire.id)
    end

    it "rejects invalid credentials" do
      post session_path, params: { galaxy_id: galaxy.id, empire_id: empire.id, password: "wrong" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:empire_id]).to be_nil
    end
  end

  describe "DELETE /session" do
    it "logs out" do
      sign_in(empire)
      delete session_path
      expect(response).to redirect_to(root_path)
      expect(session[:empire_id]).to be_nil
    end
  end
end
