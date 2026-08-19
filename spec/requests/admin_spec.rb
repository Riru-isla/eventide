require 'rails_helper'

RSpec.describe "Administration", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Admin Test", size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:commander) { galaxy.players.first.user }
  let(:administrator) { create(:user, username: "root", admin: true) }

  describe "GET /admin" do
    it "shows every galaxy and every account" do
      sign_in(administrator)

      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      # "ada" is the account; "Ada" is who they are in that galaxy.
      expect(response.body).to include("Admin Test", "root", "ada", "Ada")
      expect(response.body).to include("Inspect", "Generate galaxy")
    end

    it "reports each galaxy's settings and how far it has run" do
      sign_in(administrator)

      get admin_dashboard_path

      expect(response.body).to include(galaxy.threat_level, galaxy.awareness_level, galaxy.size)
    end

    it "says which accounts command where, and which administer" do
      sign_in(administrator)

      get admin_dashboard_path

      expect(response.body).to include("administrator", "foundry")
    end

    it "opens for an administrator who commands nowhere at all" do
      # Admin screens are about the server, not a commander, so they must not demand an
      # empire the way every game screen does.
      expect(administrator.empires).to be_empty

      sign_in(administrator)
      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
    end

    it "turns away a player, even one with an empire" do
      sign_in(commander)

      get admin_dashboard_path

      expect(response).to redirect_to(galaxies_path)
      expect(flash[:alert]).to match(/administrator/)
    end

    it "offers no way to grant administrator rights from the game" do
      sign_in(administrator)

      get admin_dashboard_path

      expect(response.body).not_to match(/Make admin|Revoke|Promote/)
      expect(response.body).to include("admin:grant")
    end
  end

  describe "the lobby" do
    it "links an administrator to the admin screens" do
      sign_in(administrator)

      get galaxies_path

      expect(response.body).to include("Administration")
    end

    it "shows a player no sign that they exist" do
      sign_in(commander)

      get galaxies_path

      expect(response.body).not_to include("Administration")
    end
  end
end
