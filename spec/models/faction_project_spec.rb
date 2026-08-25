require 'rails_helper'

RSpec.describe FactionProject, type: :model do
  subject(:project) { build(:faction_project) }

  describe "associations" do
    it { is_expected.to belong_to(:npc_faction) }
    it { is_expected.to belong_to(:system) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_numericality_of(:defence_gain).is_greater_than(0) }

    it "cannot finish before it started" do
      project.started_at_tick = 100
      project.completes_at_tick = 99

      expect(project).not_to be_valid
    end
  end

  describe ".due_by" do
    it "finds only the work that has come round" do
      done = create(:faction_project, completes_at_tick: 50)
      create(:faction_project, completes_at_tick: 51)

      expect(described_class.due_by(50)).to contain_exactly(done)
    end
  end

  describe "#ticks_remaining" do
    it "counts down and stops at zero" do
      project.completes_at_tick = 60

      expect(project.ticks_remaining(50)).to eq(10)
      expect(project.ticks_remaining(90)).to be_zero
    end
  end
end
