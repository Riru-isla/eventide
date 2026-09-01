require 'rails_helper'

RSpec.describe Combat::Balance, type: :service do
  def hull(key, cost:, damage:, shield: 10, armour: 10, hull_points: 30, signature: 1)
    instance_double(
      ShipType, key: key, name: key, build_cost: cost, damage: { hull: damage },
      combat_unit: Combat::Unit.new(key: key, name: key, category: "ship", shield: shield,
                                    armour: armour, hull: hull_points, signature: signature,
                                    damage: { shield: damage, armour: damage, hull: damage })
    )
  end

  describe "#results" do
    it "fights every hull against every other, including itself" do
      balance = described_class.new(hulls: [ hull("a", cost: 10, damage: 5), hull("b", cost: 20, damage: 5) ],
                                    budget: 200, seeds: 3)

      expect(balance.results.size).to eq(4)
      expect(balance.results.map { |r| [ r.attacker.key, r.defender.key ] })
        .to contain_exactly(%w[a a], %w[a b], %w[b a], %w[b b])
    end

    it "buys each side the same money's worth, not the same number of hulls" do
      # A capital beating twenty fighters means nothing until you know it cost as much as
      # twenty-two of them.
      cheap = hull("cheap", cost: 10, damage: 5)
      dear = hull("dear", cost: 100, damage: 5)
      balance = described_class.new(hulls: [ cheap, dear ], budget: 1_000, seeds: 1)

      duel = balance.results.find { |r| r.attacker == cheap && r.defender == dear }

      expect(duel.count).to eq(100)
      expect(duel.against).to eq(10)
    end

    it "always buys at least one, however dear the hull" do
      balance = described_class.new(hulls: [ hull("dreadnought", cost: 10_000, damage: 5) ],
                                    budget: 100, seeds: 1)

      expect(balance.results.first.count).to eq(1)
    end
  end

  describe "#dominance" do
    it "reports how often each hull wins, ignoring its own mirror" do
      strong = hull("strong", cost: 10, damage: 500)
      weak = hull("weak", cost: 10, damage: 1)
      balance = described_class.new(hulls: [ strong, weak ], budget: 100, seeds: 3)

      # The failure this exists to catch: one hull that answers everything.
      expect(balance.dominance[strong]).to eq(100)
      expect(balance.dominance[weak]).to be_zero
    end
  end

  describe "#lines" do
    subject(:lines) { described_class.new(hulls: [ hull("scout", cost: 25, damage: 5) ], budget: 100, seeds: 1).lines }

    it "prints the grid, what each hull buys, and who wins overall" do
      expect(lines.first).to include("attacker", "defender")
      expect(lines.join("\n")).to include("scout", "damage/cost", "integrity/cost")
    end

    it "shows what a hull costs and how many the budget affords" do
      expect(lines.join("\n")).to match(/scout\s+25\s+4/)
    end

    it "ranks the hulls by how often they win, so a dominant one is obvious at a glance" do
      report = described_class.new(hulls: [ hull("gunboat", cost: 10, damage: 500),
                                            hull("tender", cost: 10, damage: 1) ],
                                   budget: 100, seeds: 3).lines.join("\n")

      expect(report).to include("wins across the grid")
      expect(report).to match(/gunboat\s+100%/)
      expect(report).to match(/tender\s+0%/)
    end
  end

  describe "the catalogue it defaults to" do
    it "leaves out hulls that cannot shoot, since a duel between them never ends" do
      keys = described_class.new(budget: 1_000, seeds: 1).results.map { |r| r.attacker.key }.uniq

      expect(keys).not_to include("transport")
      expect(keys).to include("light_fighter", "battle_cruiser")
    end
  end
end
