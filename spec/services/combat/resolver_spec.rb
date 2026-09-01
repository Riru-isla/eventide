require 'rails_helper'

RSpec.describe Combat::Resolver, type: :service do
  def unit(key, shield:, armour:, hull:, damage:, signature: 1, category: "ship")
    Combat::Unit.new(key: key, name: key.to_s, category: category,
                     shield: shield, armour: armour, hull: hull, signature: signature,
                     damage: { shield: damage, armour: damage, hull: damage })
  end

  # Two shots to kill, which is where an even fight is bloody without being certain.
  let(:corvette) { unit(:corvette, shield: 10, armour: 10, hull: 40, damage: 50) }
  # Shrugs off anything that cannot out-damage its shield in one round.
  let(:battleship) { unit(:battleship, shield: 500, armour: 400, hull: 3_000, damage: 800) }

  def fight(attacker, defender, seed: 7, rounds: described_class::ROUNDS)
    described_class.new(attacker: Combat::Force.of("Attacker", attacker),
                        defender: Combat::Force.of("Defender", defender),
                        seed: seed, rounds: rounds).resolve
  end

  describe "the seed" do
    it "fights the same battle twice given the same seed" do
      first = fight({ corvette => 60 }, { corvette => 55 }, seed: 99).to_h
      second = fight({ corvette => 60 }, { corvette => 55 }, seed: 99).to_h

      expect(first).to eq(second)
    end

    it "fights a different battle given a different seed" do
      outcomes = (1..12).map { |seed| fight({ corvette => 60 }, { corvette => 55 }, seed: seed).to_h[:attacker][:losses] }

      expect(outcomes.uniq.size).to be > 1
    end

    it "carries the seed on the report, so a battle can be re-derived rather than trusted" do
      report = fight({ corvette => 5 }, { corvette => 5 }, seed: 4242)

      expect(report.seed).to eq(4242)
      expect(report.to_h[:seed]).to eq(4242)
    end

    it "picks its own seed when none is given" do
      expect(fight({ corvette => 3 }, { corvette => 3 }, seed: nil).seed).to be_present
    end
  end

  describe "shields as a rate rather than a threshold" do
    it "shrugs off small ships that cannot out-damage regeneration" do
      # Five corvettes deal 250 a round against 500 of shield: absorbed entirely, every
      # round, forever. This is what makes composition matter.
      report = fight({ corvette => 5 }, { battleship => 1 })

      expect(report.to_h[:defender][:losses]).to be_zero
      expect(report).not_to be_attacker_won
    end

    it "lets enough of them through, because mass has to win eventually" do
      # Fifty deal 2,500 a round. The shield collapses and the rest goes into the hull —
      # a hard threshold would have made the battleship immortal at any number.
      report = fight({ corvette => 50 }, { battleship => 1 })

      expect(report.outcome).to eq(:attacker)
      expect(report.to_h[:defender][:losses]).to eq(1)
    end

    it "makes winning that way cost something" do
      report = fight({ corvette => 60 }, { battleship => 1 })

      expect(report).to be_attacker_won
      expect(report.to_h[:attacker][:losses]).to be_positive
    end
  end

  describe "screening" do
    # A hull that draws fire away from the fragile ships beside it is the only reason to
    # build a defensive one in a fleet somebody else is also flying in.
    let(:screen) { unit(:screen, shield: 400, armour: 400, hull: 1_200, damage: 20, signature: 10) }

    it "pulls fire off the ships behind it" do
      alone = fight({ corvette => 100 }, { corvette => 100 }, seed: 5)
      screened = fight({ corvette => 100, screen => 10 }, { corvette => 100 }, seed: 5)

      expect(screened.to_h[:attacker][:casualties][:corvette])
        .to be < alone.to_h[:attacker][:casualties][:corvette]
    end

    it "takes the shots it drew rather than dodging them" do
      # Uniform targeting had heavy hulls soaking only their own share, so ten of them
      # saved a single corvette and came through untouched.
      report = fight({ corvette => 40, screen => 4 }, { corvette => 400 }, seed: 8)

      expect(report.to_h[:attacker][:casualties][:screen]).to be_positive
    end

    it "draws in proportion to its signature, not its numbers" do
      heavy = unit(:heavy, shield: 10, armour: 10, hull: 40, damage: 50, signature: 20)
      mixed = fight({ corvette => 20, heavy => 1 }, { corvette => 60 }, seed: 2).to_h

      # One heavy pulling twenty times a corvette's share dies well before twenty
      # corvettes of identical toughness would have.
      expect(mixed[:attacker][:casualties][:heavy]).to eq(1)
    end
  end

  describe "how much luck decides" do
    def spread(count)
      losses = (1..25).map { |seed| fight({ corvette => count }, { corvette => count }, seed: seed).to_h[:attacker][:losses] / count.to_f }
      losses.max - losses.min
    end

    it "swings in a skirmish and settles in a fleet action" do
      # Every unit rolls its own shot, so the dice pile up as fleets grow. Luck decides a
      # dogfight; at scale it only moves the margin.
      expect(spread(5)).to be > spread(500)
    end
  end

  describe "rounds" do
    it "fires both sides before either takes losses, so both can be destroyed" do
      # Defending has to cost something, or holding ground is free.
      report = fight({ corvette => 20 }, { corvette => 20 }, seed: 3, rounds: 12)

      expect(report.to_h[:attacker][:losses]).to be_positive
      expect(report.to_h[:defender][:losses]).to be_positive
    end

    it "stops early once one side is gone" do
      report = fight({ battleship => 10 }, { corvette => 1 })

      expect(report.rounds.size).to eq(1)
    end

    it "reports what each round cost" do
      report = fight({ corvette => 40 }, { corvette => 40 }, seed: 11)
      round = report.rounds.first

      expect(round[:number]).to eq(1)
      expect(round[:attacker_lost]).to be_positive
      expect(round[:defender_lost]).to be_positive
    end
  end

  describe "outcomes" do
    it "gives it to the attacker when the defenders are cleared" do
      expect(fight({ battleship => 5 }, { corvette => 2 }).outcome).to eq(:attacker)
      expect(fight({ battleship => 5 }, { corvette => 2 })).to be_attacker_won
    end

    it "gives it to the defender when the attack is wiped out" do
      expect(fight({ corvette => 3 }, { battleship => 2 }).outcome).to eq(:defender)
    end

    it "calls it a stalemate when both sides are still standing" do
      tough = unit(:tough, shield: 200, armour: 200, hull: 600, damage: 40)

      expect(fight({ tough => 30 }, { tough => 30 }).outcome).to eq(:stalemate)
    end

    it "calls it mutual destruction when neither side is left" do
      glass = unit(:glass, shield: 0, armour: 0, hull: 10, damage: 500)

      expect(fight({ glass => 40 }, { glass => 40 }, seed: 5).outcome).to eq(:mutual_destruction)
    end

    it "does not hand the ground to an attacker who failed to clear it" do
      # Six rounds is a length of engagement, not a fight to the last hull.
      report = fight({ corvette => 30 }, { battleship => 3 })

      expect(report).not_to be_attacker_won
    end
  end

  describe "the report" do
    it "names the survivors and the casualties on each side" do
      report = fight({ corvette => 50, battleship => 2 }, { corvette => 40 }, seed: 21).to_h

      expect(report[:attacker][:name]).to eq("Attacker")
      expect(report[:attacker][:survivors].keys).to include(:battleship)
      expect(report[:defender][:casualties][:corvette]).to be_positive
      expect(report[:defender][:losses]).to eq(report[:defender][:casualties].values.sum)
    end

    it "leaves a side that brought nobody out of it entirely" do
      report = fight({ corvette => 10, battleship => 0 }, { corvette => 5 }).to_h

      expect(report[:attacker][:survivors]).not_to have_key(:battleship)
    end
  end
end
