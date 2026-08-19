require 'rails_helper'

RSpec.describe GalaxyPreview, type: :service do
  subject(:preview) { described_class.new(galaxy) }

  let(:galaxy) do
    GalaxyGenerator.new(
      name: "Preview Test", size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" }, { name: "Ben", role: "warden" } ]
    ).generate
  end

  describe "#to_svg" do
    it "draws one rectangle per system, plus the background" do
      expect(preview.to_svg.scan("<rect").size).to eq(galaxy.systems.count + 1)
    end

    it "is a self-contained SVG document" do
      svg = preview.to_svg

      expect(svg).to start_with("<svg xmlns=")
      expect(svg).to end_with("</svg>")
    end

    it "labels every sector and rings every capital and home" do
      svg = preview.to_svg

      galaxy.sectors.each { |sector| expect(svg).to include(sector.name) }
      expect(svg.scan("<circle").size).to eq(galaxy.npc_factions.count + galaxy.empires.count + 1)
    end

    it "names the galaxy and its core in the caption" do
      expect(preview.to_svg).to include("Preview Test", "core #{galaxy.core_x},#{galaxy.core_y}")
    end

    it "escapes names rather than letting them break the document" do
      galaxy.sectors.first.update!(name: "Ada & <Ben>")

      expect(preview.to_svg).to include("Ada &amp; &lt;Ben&gt;")
    end
  end

  describe "#summary" do
    it "reports one row per sector, deepest last" do
      rows = preview.summary

      expect(rows.size).to eq(galaxy.sectors.count)
      expect(rows.map { |row| row[:power_level] }).to eq(rows.map { |row| row[:power_level] }.sort)
      expect(rows.last[:kind]).to eq("core")
    end

    it "counts the systems in each sector and how many are garrisoned" do
      row = preview.summary.find { |entry| entry[:kind] == "core" }
      core = galaxy.core_sector

      expect(row[:systems]).to eq(core.systems.count)
      expect(row[:garrisoned]).to eq(core.systems.where.not(npc_faction_id: nil).count)
      expect(row[:faction]).to eq(core.npc_faction.name)
    end

    it "shows the spawn sector as garrisoned by nobody" do
      row = preview.summary.find { |entry| entry[:kind] == "spawn" }

      expect(row[:garrisoned]).to be_zero
      expect(row[:faction]).to be_nil
    end
  end

  describe "#frontier" do
    it "reports how far each commander is from their first fight and first capital" do
      rows = preview.frontier

      expect(rows.map { |row| row[:player] }).to contain_exactly("Ada", "Ben")
      expect(rows.map { |row| row[:garrison_ticks] }).to all(be_positive)
      # The capital is the objective behind the garrison, so it is never the nearer of the two.
      expect(rows).to all(satisfy { |row| row[:capital_ticks] >= row[:garrison_ticks] })
    end

    it "skips a commander with no fleet to measure the trip with" do
      galaxy.fleets.destroy_all

      expect(preview.frontier).to be_empty
    end

    it "reports nothing when there is no enemy on the map yet" do
      galaxy.systems.update_all(npc_faction_id: nil)

      expect(preview.frontier).to be_empty
    end
  end
end
