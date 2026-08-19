require 'rails_helper'

RSpec.describe "Users", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "User Test",
      size: "tiny",
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
    it "creates an account and sends them to the lobby to pick a galaxy" do
      expect {
        post user_registration_path, params: {
          user: {
            username: "ben",
            password: "secret123",
            password_confirmation: "secret123"
          }
        }
      }.to change(User, :count).by(1)

      # Signing up no longer founds an empire: which galaxy, and which role, comes next.
      expect(User.last.players).to be_empty
      expect(response).to redirect_to(galaxies_path)
    end

    it "rejects mismatched passwords" do
      expect {
        post user_registration_path, params: {
          user: {
            username: "ben",
            password: "secret123",
            password_confirmation: "wrong"
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
