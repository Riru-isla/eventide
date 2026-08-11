require 'rails_helper'

RSpec.describe Technology, type: :model do
  describe ".find" do
    it "looks a technology up by key" do
      expect(described_class.find("laser_technology").name).to eq("Laser Technology")
    end

    it "returns nil for an unknown key" do
      expect(described_class.find("warp_theory")).to be_nil
    end

    it "raises for an unknown key when using find!" do
      expect { described_class.find!("warp_theory") }.to raise_error(KeyError)
    end
  end

  describe ".in_category and .with_effect" do
    it "groups by category" do
      expect(described_class.in_category("military").map(&:key))
        .to contain_exactly("weapons_technology", "armor_technology", "laser_technology")
    end

    it "finds every technology sharing an effect, so bonuses can stack" do
      expect(described_class.with_effect(:weapons).map(&:key))
        .to contain_exactly("weapons_technology", "laser_technology")
    end

    it "only uses known categories" do
      expect(described_class.all.map(&:category).uniq - described_class::CATEGORIES).to be_empty
    end
  end

  describe "#research_cost" do
    it "charges the base cost for the first level" do
      expect(described_class.find("extraction_technology").research_cost(0))
        .to eq(metal: 400, crystal: 200)
    end

    it "doubles with each level" do
      technology = described_class.find("extraction_technology")

      expect(technology.research_cost(3)[:metal]).to eq(technology.research_cost(2)[:metal] * 2)
    end
  end

  describe "#research_ticks" do
    it "grows with level" do
      technology = described_class.find("extraction_technology")

      expect(technology.research_ticks(2)).to be > technology.research_ticks(1)
    end

    it "shortens with a faster lab" do
      technology = described_class.find("extraction_technology")

      expect(technology.research_ticks(1, speed_multiplier: 0.5))
        .to be < technology.research_ticks(1)
    end

    it "never drops below a single tick" do
      expect(described_class.find("extraction_technology").research_ticks(0, speed_multiplier: 0.0001)).to eq(1)
    end
  end

  describe "prerequisites" do
    it "names what a locked technology needs" do
      expect(described_class.find("laser_technology").requirement_labels)
        .to eq([ "Research Center 3", "Energy Technology 2", "Weapons Technology 2" ])
    end

    it "only depends on technologies that exist" do
      described_class.all.each do |technology|
        technology.requires.each_key do |key|
          expect(described_class.find(key)).to be_present, "#{technology.key} requires unknown #{key}"
        end
      end
    end

    it "has at least one technology available from a level 1 Research Center" do
      expect(described_class.all.select { |t| t.requires_center <= 1 && t.requires.empty? }).not_to be_empty
    end
  end
end
