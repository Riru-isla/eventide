require 'rails_helper'

RSpec.describe Empire, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:player).optional }
    it { is_expected.to have_one(:npc_faction).dependent(:destroy) }
    it { is_expected.to have_many(:planets).dependent(:destroy) }
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to belong_to(:home_system).class_name("System").optional }
    it { is_expected.to have_many(:systems).dependent(:nullify) }
    it { is_expected.to have_many(:fleets).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:role).in_array(Empire::ROLES) }
    it { is_expected.to validate_numericality_of(:metal).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:crystal).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:energy).is_greater_than_or_equal_to(0) }
  end

  describe "who is driving" do
    it "is a commander's empire by default" do
      expect(build(:empire)).to be_run_by_player
    end

    it "carries a name of its own rather than deriving one" do
      # Before factions were empires this was "#{player.name}'s Empire". A faction has no
      # player to derive from, so the name belongs to the empire.
      expect(build(:empire, name: "Ada's Empire").name).to eq("Ada's Empire")
    end

    it "needs no account when the AI drives it" do
      faction = build(:empire, :artificial)

      expect(faction).to be_run_by_npc
      expect(faction.player).to be_nil
      expect(faction).to be_valid
    end

    it "carries its own role rather than a nil for anything downstream to guard against" do
      expect(build(:empire, :artificial).role).to eq(Empire::NPC_ROLE)
    end

    it "does not offer that role to commanders joining a galaxy" do
      expect(Empire::COMMANDER_ROLES).not_to include(Empire::NPC_ROLE)
    end

    it "still insists on a role it knows" do
      expect(build(:empire, role: "tourist")).not_to be_valid
    end

    it "separates the two with scopes" do
      commanded = create(:empire)
      artificial = create(:empire, :artificial)

      expect(Empire.commanded).to include(commanded)
      expect(Empire.commanded).not_to include(artificial)
      expect(Empire.artificial).to contain_exactly(artificial)
    end

    it "takes no resource bonus from that role, so its edge is tempo not yield" do
      expect(build(:empire, :artificial).resource_bonus(:metal)).to eq(1.0)
    end
  end

  describe "#resource_bonus" do
    it "gives cultivators a crystal bonus" do
      empire = build(:empire, role: "cultivator")
      expect(empire.resource_bonus(:crystal)).to eq(1.5)
    end

    it "gives foundries a metal bonus" do
      empire = build(:empire, role: "foundry")
      expect(empire.resource_bonus(:metal)).to eq(1.5)
    end

    it "gives wardens an energy bonus" do
      empire = build(:empire, role: "warden")
      expect(empire.resource_bonus(:energy)).to eq(1.5)
    end

    it "returns 1.0 for non-matching resources" do
      empire = build(:empire, role: "cultivator")
      expect(empire.resource_bonus(:metal)).to eq(1.0)
    end
  end
end
