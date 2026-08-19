require 'rails_helper'

RSpec.describe "Research", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Research Test",
      size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }
  let(:planet) { empire.planet }

  def set_center(level)
    planet.structures.find_or_create_by!(kind: "research_center") { |s| s.level = 0 }.update!(level: level)
  end

  before do
    sign_in(user)
    empire.update!(metal: 100_000, crystal: 100_000)
  end

  describe "GET /research" do
    it "lists every technology, grouped by category" do
      get research_path

      expect(response).to have_http_status(:ok)
      Technology.all.each { |technology| expect(response.body).to include(technology.name) }
      Technology::CATEGORIES.each { |category| expect(response.body).to include(category) }
    end

    it "tells the player to build a Research Center when there is none" do
      get research_path

      expect(response.body).to include("No Research Center on this planet")
    end

    it "shows what a locked technology is missing" do
      set_center(1)

      get research_path

      expect(response.body).to include("Locked")
      expect(response.body).to include("Research Center 3")
    end

    it "reports the effect of a researched technology" do
      set_center(1)
      empire.technologies.create!(kind: "extraction_technology", level: 3)

      get research_path

      expect(response.body).to include("+15% extraction")
    end

    it "reports every effect kind without falling over" do
      set_center(3)
      Technology.all.each { |t| empire.technologies.create!(kind: t.key, level: 2) }

      get research_path

      expect(response.body).to include("+10% extraction")
      expect(response.body).to include("+10% energy")
      expect(response.body).to include("+20% storage")
      expect(response.body).to include("−6% build time")
      expect(response.body).to include("−10% travel time")
      expect(response.body).to include("+10% fleet attack")
      expect(response.body).to include("20% of a fleet survives a failed attack")
    end

    it "shows the project under way" do
      set_center(1)
      empire.reload.research.start!("extraction_technology")

      get research_path

      expect(response.body).to include("Extraction Technology")
      expect(response.body).to include("left")
    end

    it "redirects when the empire has no planet" do
      planet.destroy!

      get research_path

      expect(response).to redirect_to(galaxies_path)
    end

    it "requires a signed-in user" do
      sign_out(user)

      get research_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /research/:id" do
    before { set_center(1) }

    it "starts the project and charges the empire" do
      cost = Technology.find("extraction_technology").research_cost(0)

      expect { post start_research_path("extraction_technology") }
        .to change(ResearchOrder, :count).by(1)
        .and change { empire.reload.metal }.by(-cost[:metal])

      expect(flash[:notice]).to match(/Research started: Extraction Technology/)
      expect(response).to redirect_to(research_path)
    end

    it "refuses a locked technology and says why" do
      expect { post start_research_path("laser_technology") }.not_to change(ResearchOrder, :count)

      expect(flash[:alert]).to match(/Research Center 3/)
    end

    it "refuses an unknown technology" do
      post start_research_path("warp_theory")

      expect(flash[:alert]).to match(/unknown technology/)
    end

    it "refuses a second project while one is under way" do
      post start_research_path("extraction_technology")

      expect { post start_research_path("energy_technology") }.not_to change(ResearchOrder, :count)
      expect(flash[:alert]).to match(/already researching/)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { post start_research_path("extraction_technology") }.not_to change(ResearchOrder, :count)
      expect(flash[:alert]).to match(/needs/)
    end

    it "redirects when the empire has no planet" do
      planet.destroy!

      post start_research_path("extraction_technology")

      expect(response).to redirect_to(galaxies_path)
    end

    it "answers a Turbo request with streams instead of a redirect" do
      post start_research_path("extraction_technology"), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="flash"')
      expect(response.body).to include('target="hud"')
      expect(response.body).to include('action="update" target="planet-main"')
    end

    it "reports a failure through the Turbo stream too" do
      post start_research_path("laser_technology"), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Could not start research")
    end
  end
end
