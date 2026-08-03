require 'rails_helper'

RSpec.describe GalaxiesHelper, type: :helper do
  describe "#sector_color" do
    it "returns red for core sectors" do
      sector = build(:sector, kind: "core", empire: nil, npc_faction: nil)
      expect(helper.sector_color(sector)).to eq("#ef4444")
    end

    it "returns green for resource sectors" do
      sector = build(:sector, kind: "resource", empire: nil, npc_faction: nil)
      expect(helper.sector_color(sector)).to eq("#10b981")
    end

    it "returns gray for empty sectors" do
      sector = build(:sector, kind: "empty", empire: nil, npc_faction: nil)
      expect(helper.sector_color(sector)).to eq("#4b5563")
    end
  end
end
