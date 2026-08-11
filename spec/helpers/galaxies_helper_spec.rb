require 'rails_helper'

RSpec.describe GalaxiesHelper, type: :helper do
  let(:galaxy) { create(:galaxy, width: 15, height: 15) }
  let(:empire) { create(:empire, galaxy: galaxy) }
  let(:colors) { { empire.id => "#79d2e2" } }

  describe "#sector_color" do
    it "uses the prebuilt map for an owned sector, without touching the database" do
      sector = create(:sector, galaxy: galaxy, empire: empire)

      expect(helper.sector_color(sector, colors)).to eq("#79d2e2")
    end

    it "uses the faction's own colour for NPC sectors" do
      faction = create(:npc_faction, galaxy: galaxy, color: "#a855f7")
      sector = create(:sector, galaxy: galaxy, npc_faction: faction)

      expect(helper.sector_color(sector, colors)).to eq("#a855f7")
    end

    it "marks the core red and resource sectors green" do
      expect(helper.sector_color(create(:sector, galaxy: galaxy, kind: "core"), colors)).to eq("#ef4444")
      expect(helper.sector_color(create(:sector, galaxy: galaxy, kind: "resource"), colors)).to eq("#57be8e")
    end

    it "leaves empty space dim" do
      expect(helper.sector_color(create(:sector, galaxy: galaxy, kind: "empty"), colors)).to eq(described_class::EMPTY_COLOR)
    end

    it "falls back to dim when an owner is missing from the map" do
      sector = create(:sector, galaxy: galaxy, empire: create(:empire, galaxy: galaxy))

      expect(helper.sector_color(sector, colors)).to eq(described_class::EMPTY_COLOR)
    end
  end

  describe "#empire_color" do
    it "gives each empire a distinct colour" do
      expect(helper.empire_color(0)).not_to eq(helper.empire_color(1))
    end

    it "wraps around rather than running out" do
      expect(helper.empire_color(described_class::EMPIRE_COLORS.size)).to eq(helper.empire_color(0))
    end
  end

  describe "#sector_position" do
    it "puts the core at the centre of the map" do
      core = create(:sector, galaxy: galaxy, x: 7, y: 7)
      middle = described_class::MAP_VIEWBOX / 2.0

      expect(helper.sector_position(core, galaxy)).to eq([ middle, middle ])
    end

    it "keeps the furthest corner inside the disc" do
      corner = create(:sector, galaxy: galaxy, x: 0, y: 0)
      middle = described_class::MAP_VIEWBOX / 2.0

      x, y = helper.sector_position(corner, galaxy)
      radius = Math.sqrt(((x - middle)**2) + ((y - middle)**2))

      expect(radius).to be <= described_class::MAP_RADIUS + 0.5
    end

    it "places sectors further from the centre the further out they sit" do
      near = create(:sector, galaxy: galaxy, x: 8, y: 7)
      far = create(:sector, galaxy: galaxy, x: 13, y: 7)
      middle = described_class::MAP_VIEWBOX / 2.0

      expect(far_from(far, galaxy, middle)).to be > far_from(near, galaxy, middle)
    end

    def far_from(sector, galaxy, middle)
      x, y = helper.sector_position(sector, galaxy)
      Math.sqrt(((x - middle)**2) + ((y - middle)**2))
    end
  end

  describe "#sector_radius" do
    it "draws the core and home worlds larger than empty space" do
      core = helper.sector_radius(build(:sector, kind: "core"))
      home = helper.sector_radius(build(:sector, kind: "home"))
      empty = helper.sector_radius(build(:sector, kind: "empty"))

      expect(core).to be > home
      expect(home).to be > empty
    end

    it "draws a held sector larger than an unheld one of the same kind" do
      held = helper.sector_radius(build(:sector, kind: "resource", empire: empire))
      loose = helper.sector_radius(build(:sector, kind: "resource"))

      expect(held).to be > loose
    end
  end
end
