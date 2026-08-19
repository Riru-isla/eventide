require 'rails_helper'

RSpec.describe FactionAwakening, type: :service do
  subject(:awakening) { described_class.new(galaxy) }

  let(:galaxy) { GalaxyGenerator.new(name: "Awakening", size: "tiny", player_configs: []).generate }
  let(:frontier) { galaxy.npc_factions.find_by(aggression: "dormant") }
  let(:neighbour) { frontier.neighbours.standing.slumbering.first }

  # The roll is the only randomness in here, so forcing it makes both branches testable.
  def roll(outcome)
    allow(Random).to receive(:rand).and_return(outcome == :win ? 0.0 : 1.0)
  end

  describe "#contact!" do
    it "rouses a faction that has seen a player fleet in its space" do
      awakening.contact!(frontier)

      expect(frontier.reload).to be_roused
      expect(frontier.aggression).to eq("aware")
    end

    it "rouses one that had no reason to care, so nowhere is scoutable with impunity" do
      deep = galaxy.npc_factions.find_by(aggression: "unaware")

      awakening.contact!(deep)

      expect(deep.reload).to be_roused
    end

    it "leaves a faction that has already fallen alone" do
      frontier.update!(fallen_at_tick: 5, aggression: :unaware)

      awakening.contact!(frontier)

      expect(frontier.reload.aggression).to eq("unaware")
    end

    it "does not disturb one that is already up" do
      frontier.update!(aggression: :hunting)

      awakening.contact!(frontier)

      expect(frontier.reload.aggression).to eq("hunting")
    end

    it "shrugs off a system nobody holds" do
      expect { awakening.contact!(nil) }.not_to raise_error
    end
  end

  describe "#captured!" do
    it "does nothing when the system taken was not the capital" do
      ordinary = frontier.systems.where.not(id: frontier.capital_system_id).first

      awakening.captured!(ordinary, frontier)

      expect(frontier.reload).not_to be_fallen
    end

    it "ends the faction when its capital falls" do
      galaxy.update!(current_tick: 40)

      awakening.captured!(frontier.capital_system, frontier)

      expect(frontier.reload).to be_fallen
      expect(frontier.fallen_at_tick).to eq(40)
    end

    it "rouses a neighbour outright when the roll lands" do
      roll(:win)
      bordering = neighbour

      awakening.captured!(frontier.capital_system, frontier)

      expect(bordering.reload).to be_roused
    end

    it "starts a clock on a neighbour that had none when the roll fails" do
      roll(:lose)
      bordering = neighbour
      bordering.update!(wake_at_tick: nil)
      galaxy.update!(current_tick: 7)

      awakening.captured!(frontier.capital_system, frontier)

      expect(bordering.reload.wake_at_tick).to eq(7 + bordering.wake_delay)
      expect(bordering).not_to be_roused
    end

    it "pulls in a clock that was already running, so trouble next door still counts" do
      roll(:lose)
      bordering = neighbour
      bordering.update!(wake_at_tick: 1_000)
      galaxy.update!(current_tick: 0)

      awakening.captured!(frontier.capital_system, frontier)

      expect(bordering.reload.wake_at_tick).to eq(600)
    end

    it "never reaches anything that does not border the fallen faction" do
      roll(:lose)
      strangers = galaxy.npc_factions.where.not(id: frontier.neighbours.select(:id)).where.not(id: frontier.id)
      before = strangers.pluck(:id, :wake_at_tick, :aggression)

      awakening.captured!(frontier.capital_system, frontier)

      expect(galaxy.npc_factions.where(id: strangers.select(:id)).pluck(:id, :wake_at_tick, :aggression))
        .to match_array(before)
    end

    it "ignores a faction that is already gone" do
      frontier.update!(fallen_at_tick: 3)

      expect { awakening.captured!(frontier.capital_system, frontier) }
        .not_to change { frontier.reload.fallen_at_tick }
    end

    it "shrugs off a system nobody held" do
      system = galaxy.systems.find_by(npc_faction_id: nil)

      expect { awakening.captured!(system, nil) }.not_to raise_error
    end
  end

  describe "#advance!" do
    it "rouses a faction whose clock has run out" do
      frontier.update!(wake_at_tick: 10)
      galaxy.update!(current_tick: 10)

      awakening.advance!

      expect(frontier.reload).to be_roused
    end

    it "leaves one whose clock has not" do
      frontier.update!(wake_at_tick: 500)
      galaxy.update!(current_tick: 499)

      awakening.advance!

      expect(frontier.reload).not_to be_roused
    end

    it "never rouses a faction with no clock, however long the galaxy runs" do
      # The whole point: nothing beyond the front has a clock, so a slow group is never
      # overtaken by an escalation they did not provoke.
      unprovoked = galaxy.npc_factions.where(wake_at_tick: nil)
      galaxy.update!(current_tick: 500_000)

      awakening.advance!

      expect(unprovoked.reload.map(&:roused?)).to all(be(false))
    end

    it "leaves the fallen where they lie" do
      frontier.update!(wake_at_tick: 1, fallen_at_tick: 1, aggression: :unaware)
      galaxy.update!(current_tick: 50)

      awakening.advance!

      expect(frontier.reload.aggression).to eq("unaware")
    end
  end
end
