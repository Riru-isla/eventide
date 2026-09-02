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
    described_class.new(forces: [ Combat::Force.of("Attacker", attacker),
                                  Combat::Force.of("Defender", defender) ],
                        seed: seed, rounds: rounds).resolve
  end

  def losses(report, side) = report.to_h[:forces][side][:losses]

  def casualties(report, side) = report.to_h[:forces][side][:casualties]

  describe "the seed" do
    it "fights the same battle twice given the same seed" do
      first = fight({ corvette => 60 }, { corvette => 55 }, seed: 99).to_h
      second = fight({ corvette => 60 }, { corvette => 55 }, seed: 99).to_h

      expect(first).to eq(second)
    end

    it "fights a different battle given a different seed" do
      outcomes = (1..12).map { |seed| fight({ corvette => 60 }, { corvette => 55 }, seed: seed).to_h[:forces]["Attacker"][:losses] }

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

      expect(losses(report, "Defender")).to be_zero
      expect(report).not_to be_won("Attacker")
    end

    it "lets enough of them through, because mass has to win eventually" do
      # Fifty deal 2,500 a round. The shield collapses and the rest goes into the hull —
      # a hard threshold would have made the battleship immortal at any number.
      report = fight({ corvette => 50 }, { battleship => 1 })

      expect(report.victor).to eq("Attacker")
      expect(losses(report, "Defender")).to eq(1)
    end

    it "makes winning that way cost something" do
      report = fight({ corvette => 60 }, { battleship => 1 })

      expect(report).to be_won("Attacker")
      expect(losses(report, "Attacker")).to be_positive
    end
  end

  describe "screening" do
    # A hull that draws fire away from the fragile ships beside it is the only reason to
    # build a defensive one in a fleet somebody else is also flying in.
    let(:screen) { unit(:screen, shield: 400, armour: 400, hull: 1_200, damage: 20, signature: 10) }

    it "pulls fire off the ships behind it" do
      alone = fight({ corvette => 100 }, { corvette => 100 }, seed: 5)
      screened = fight({ corvette => 100, screen => 10 }, { corvette => 100 }, seed: 5)

      expect(screened.to_h[:forces]["Attacker"][:casualties][:corvette])
        .to be < alone.to_h[:forces]["Attacker"][:casualties][:corvette]
    end

    it "takes the shots it drew rather than dodging them" do
      # Uniform targeting had heavy hulls soaking only their own share, so ten of them
      # saved a single corvette and came through untouched.
      report = fight({ corvette => 40, screen => 4 }, { corvette => 400 }, seed: 8)

      expect(casualties(report, "Attacker")[:screen]).to be_positive
    end

    it "draws in proportion to its signature, not its numbers" do
      heavy = unit(:heavy, shield: 10, armour: 10, hull: 40, damage: 50, signature: 20)
      mixed = fight({ corvette => 20, heavy => 1 }, { corvette => 60 }, seed: 2)

      # One heavy pulling twenty times a corvette's share dies well before twenty
      # corvettes of identical toughness would have.
      expect(casualties(mixed, "Attacker")[:heavy]).to eq(1)
    end
  end

  describe "how much luck decides" do
    def spread(count)
      losses = (1..25).map { |seed| fight({ corvette => count }, { corvette => count }, seed: seed).to_h[:forces]["Attacker"][:losses] / count.to_f }
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

      expect(losses(report, "Attacker")).to be_positive
      expect(losses(report, "Defender")).to be_positive
    end

    it "stops early once one side is gone" do
      report = fight({ battleship => 10 }, { corvette => 1 })

      expect(report.rounds.size).to eq(1)
    end

    it "reports what each round cost" do
      report = fight({ corvette => 40 }, { corvette => 40 }, seed: 11)
      round = report.rounds.first

      expect(round[:number]).to eq(1)
      expect(round[:losses]["Attacker"]).to be_positive
      expect(round[:losses]["Defender"]).to be_positive
    end
  end

  describe "outcomes" do
    it "gives it to the attacker when the defenders are cleared" do
      expect(fight({ battleship => 5 }, { corvette => 2 }).victor).to eq("Attacker")
      expect(fight({ battleship => 5 }, { corvette => 2 })).to be_won("Attacker")
    end

    it "gives it to the defender when the attack is wiped out" do
      expect(fight({ corvette => 3 }, { battleship => 2 }).victor).to eq("Defender")
    end

    it "calls it a stalemate when both sides are still standing" do
      tough = unit(:tough, shield: 200, armour: 200, hull: 600, damage: 40)

      expect(fight({ tough => 30 }, { tough => 30 }).outcome).to eq(:stalemate)
    end

    it "calls it mutual destruction when neither side is left" do
      glass = unit(:glass, shield: 0, armour: 0, hull: 10, damage: 500)

      expect(fight({ glass => 40 }, { glass => 40 }, seed: 5).outcome).to eq(:annihilation)
    end

    it "does not hand the ground to an attacker who failed to clear it" do
      # Six rounds is a length of engagement, not a fight to the last hull.
      report = fight({ corvette => 30 }, { battleship => 3 })

      expect(report).not_to be_won("Attacker")
    end
  end

  describe "the report" do
    it "names the survivors and the casualties on each side" do
      report = fight({ corvette => 50, battleship => 2 }, { corvette => 40 }, seed: 21).to_h

      expect(report[:forces].keys).to contain_exactly("Attacker", "Defender")
      expect(report[:forces]["Attacker"][:survivors].keys).to include(:battleship)
      expect(report[:forces]["Defender"][:casualties][:corvette]).to be_positive
      expect(report[:forces]["Defender"][:losses]).to eq(report[:forces]["Defender"][:casualties].values.sum)
    end

    it "leaves a side that brought nobody out of it entirely" do
      report = fight({ corvette => 10, battleship => 0 }, { corvette => 5 }).to_h

      expect(report[:forces]["Attacker"][:survivors]).not_to have_key(:battleship)
    end
  end

  describe "more than two sides" do
    def melee(*forces, seed: 7, rounds: described_class::ROUNDS)
      described_class.new(forces: forces, seed: seed, rounds: rounds).resolve
    end

    def contingent(name, composition, allegiance)
      Combat::Force.of(name, composition, allegiance: allegiance)
    end

    it "never lets allies shoot each other" do
      # Two commanders storming the same faction. Left alone in the field with nobody
      # hostile, a coalition has nothing to resolve at all.
      ada = contingent("Ada", { corvette => 40 }, "commanders")
      ben = contingent("Ben", { corvette => 40 }, "commanders")

      report = melee(ada, ben)

      expect(report.rounds).to be_empty
      expect(report.to_h[:forces].values.sum { |side| side[:losses] }).to be_zero
    end

    it "lets a coalition take a fight none of them could take alone" do
      # Fifteen corvettes wear a battleship down without finishing it. Thirty, arriving as
      # two commanders who happen to be on the same side, take it.
      alone = melee(contingent("Ada", { corvette => 15 }, "commanders"),
                    contingent("Faction", { battleship => 1 }, "faction"))
      together = melee(contingent("Ada", { corvette => 15 }, "commanders"),
                       contingent("Ben", { corvette => 15 }, "commanders"),
                       contingent("Faction", { battleship => 1 }, "faction"))

      expect(alone.victor).not_to eq("commanders")
      expect(together.victor).to eq("commanders")
    end

    it "spreads incoming fire across a coalition rather than each absorbing its own share" do
      report = melee(contingent("Ada", { corvette => 30 }, "commanders"),
                     contingent("Ben", { corvette => 30 }, "commanders"),
                     contingent("Faction", { battleship => 3 }, "faction"))

      losses = report.to_h[:forces]
      expect(losses["Ada"][:losses]).to be_positive
      expect(losses["Ben"][:losses]).to be_positive
    end

    it "resolves a free-for-all where everyone is hostile to everyone" do
      report = melee(contingent("Ada", { corvette => 60 }, "ada"),
                     contingent("Rim Marauders", { corvette => 60 }, "rim"),
                     contingent("Iron Covenant", { corvette => 60 }, "iron"),
                     rounds: 12)

      expect(report.to_h[:forces].values.map { |s| s[:losses] }).to all(be_positive)
      expect(report.standing.size).to be < 3
    end

    it "stops once only one side is left standing, however many started" do
      report = melee(contingent("Ada", { battleship => 20 }, "commanders"),
                     contingent("Ben", { battleship => 20 }, "commanders"),
                     contingent("Rim", { corvette => 2 }, "rim"),
                     contingent("Iron", { corvette => 2 }, "iron"))

      expect(report.victor).to eq("commanders")
      expect(report.rounds.size).to be < described_class::ROUNDS
    end

    it "reports every side's losses round by round" do
      report = melee(contingent("Ada", { corvette => 50 }, "commanders"),
                     contingent("Ben", { corvette => 50 }, "commanders"),
                     contingent("Faction", { corvette => 90 }, "faction"))

      expect(report.rounds.first[:losses].keys).to contain_exactly("Ada", "Ben", "Faction")
    end

    it "counts a side that fights for itself as its own allegiance" do
      lone = Combat::Force.of("Drifter", { corvette => 5 })

      expect(lone.allegiance).to eq("Drifter")
      expect(lone).not_to be_allied_with(Combat::Force.of("Other", { corvette => 5 }))
    end
  end
end
