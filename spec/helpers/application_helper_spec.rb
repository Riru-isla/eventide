require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#number_with_sign" do
    it "prefixes positive numbers with a plus" do
      expect(helper.number_with_sign(78)).to eq("+78")
    end

    it "prefixes negative numbers with a true minus sign" do
      expect(helper.number_with_sign(-102)).to eq("−102")
    end

    it "treats zero as positive" do
      expect(helper.number_with_sign(0)).to eq("+0")
    end

    it "delimits thousands" do
      expect(helper.number_with_sign(12_480)).to eq("+12,480")
    end

    it "rounds fractional values" do
      expect(helper.number_with_sign(45.4)).to eq("+45")
    end
  end

  describe "#structure_glyph_tone" do
    it "tints metal and crystal extractors differently" do
      expect(helper.structure_glyph_tone(Structure.find("metal_extractor"))).to eq("text-metal")
      expect(helper.structure_glyph_tone(Structure.find("crystal_extractor"))).to eq("text-crystal")
    end

    it "tints energy structures amber" do
      expect(helper.structure_glyph_tone(Structure.find("solar_array"))).to eq("text-amber")
    end

    it "leaves facilities neutral" do
      expect(helper.structure_glyph_tone(Structure.find("shipyard"))).to eq("text-ink-2")
    end
  end
end
