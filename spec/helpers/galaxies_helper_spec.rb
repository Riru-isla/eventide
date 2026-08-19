require 'rails_helper'

RSpec.describe GalaxiesHelper, type: :helper do
  let(:galaxy) { create(:galaxy, width: 15, height: 15) }
  let(:empire) { create(:empire, galaxy: galaxy) }
  let(:colors) { { empire.id => "#79d2e2" } }

  describe "#system_color" do
    it "uses the prebuilt map for an owned system, without touching the database" do
      system = create(:system, galaxy: galaxy, empire: empire)

      expect(helper.system_color(system, colors)).to eq("#79d2e2")
    end

    it "uses the faction's own colour for NPC systems" do
      faction = create(:npc_faction, galaxy: galaxy, color: "#a855f7")
      system = create(:system, galaxy: galaxy, npc_faction: faction)

      expect(helper.system_color(system, colors)).to eq("#a855f7")
    end

    it "marks the core red and resource systems green" do
      expect(helper.system_color(create(:system, galaxy: galaxy, kind: "core"), colors)).to eq("#ef4444")
      expect(helper.system_color(create(:system, galaxy: galaxy, kind: "resource"), colors)).to eq("#57be8e")
    end

    it "leaves empty space dim" do
      expect(helper.system_color(create(:system, galaxy: galaxy, kind: "empty"), colors)).to eq(described_class::EMPTY_COLOR)
    end

    it "falls back to dim when an owner is missing from the map" do
      system = create(:system, galaxy: galaxy, empire: create(:empire, galaxy: galaxy))

      expect(helper.system_color(system, colors)).to eq(described_class::EMPTY_COLOR)
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

  describe "#system_position" do
    it "puts the core at the centre of the map" do
      core = create(:system, galaxy: galaxy, x: 7, y: 7)
      middle = described_class::MAP_VIEWBOX / 2.0

      expect(helper.system_position(core, galaxy)).to eq([ middle, middle ])
    end

    it "keeps the furthest corner inside the disc" do
      corner = create(:system, galaxy: galaxy, x: 0, y: 0)
      middle = described_class::MAP_VIEWBOX / 2.0

      x, y = helper.system_position(corner, galaxy)
      radius = Math.sqrt(((x - middle)**2) + ((y - middle)**2))

      expect(radius).to be <= described_class::MAP_RADIUS + 0.5
    end

    it "places systems further from the centre the further out they sit" do
      near = create(:system, galaxy: galaxy, x: 8, y: 7)
      far = create(:system, galaxy: galaxy, x: 13, y: 7)
      middle = described_class::MAP_VIEWBOX / 2.0

      expect(far_from(far, galaxy, middle)).to be > far_from(near, galaxy, middle)
    end

    def far_from(system, galaxy, middle)
      x, y = helper.system_position(system, galaxy)
      Math.sqrt(((x - middle)**2) + ((y - middle)**2))
    end
  end

  describe "#system_radius" do
    it "draws the core and home worlds larger than empty space" do
      core = helper.system_radius(build(:system, kind: "core"))
      home = helper.system_radius(build(:system, kind: "home"))
      empty = helper.system_radius(build(:system, kind: "empty"))

      expect(core).to be > home
      expect(home).to be > empty
    end

    it "draws a held system larger than an unheld one of the same kind" do
      held = helper.system_radius(build(:system, kind: "resource", empire: empire))
      loose = helper.system_radius(build(:system, kind: "resource"))

      expect(held).to be > loose
    end
  end
end
