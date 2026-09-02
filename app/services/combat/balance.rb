module Combat
  # Fights every hull against every other at equal investment and reports who wins.
  #
  # The point is that no hull should be the answer to everything. Three flaws in the damage
  # model were found by hand-running matchups a few at a time, and each took several rounds
  # of guessing; this runs the whole grid at once.
  #
  # Equal *cost*, never equal numbers — a battle cruiser beating twenty light fighters
  # tells you nothing until you know it cost the same as twenty-two of them.
  class Balance
    DEFAULT_BUDGET = 60_000
    SEEDS = 9

    Result = Data.define(:attacker, :defender, :win_rate, :count, :against)

    def initialize(hulls: ShipType.all.reject { |hull| hull.damage[:hull].zero? },
                   budget: DEFAULT_BUDGET, rounds: Resolver::ROUNDS, seeds: SEEDS)
      @hulls = hulls
      @budget = budget
      @rounds = rounds
      @seeds = seeds
    end

    def results
      @results ||= @hulls.flat_map do |attacker|
        @hulls.map { |defender| duel(attacker, defender) }
      end
    end

    # How often each hull wins across the whole grid. A hull far above the rest is the
    # answer to everything, which is the failure this exists to catch.
    def dominance
      results.reject { |r| r.attacker == r.defender }
             .group_by(&:attacker)
             .transform_values { |rows| (rows.sum(&:win_rate) / rows.size.to_f).round }
    end

    # What a hull buys for the money. A win rate says which hull is wrong; these say why.
    def economics
      @hulls.map do |hull|
        unit = hull.combat_unit
        integrity = unit.shield + unit.armour + unit.hull

        { key: hull.key, cost: hull.build_cost, per_budget: affordable(hull),
          damage_per_cost: (unit.damage[:hull] / hull.build_cost.to_f).round(3),
          integrity_per_cost: (integrity / hull.build_cost.to_f).round(2),
          shots_per_budget: affordable(hull) }
      end
    end

    def lines
      keys = @hulls.map(&:key)
      header = format("%-16s %s", "attacker \\ defender", keys.map { |k| k[0, 9].rjust(11) }.join)

      rows = @hulls.map do |attacker|
        cells = keys.map { |key| "#{find(attacker, key).win_rate}%".rjust(11) }
        format("%-16s %s", attacker.key[0, 16], cells.join)
      end

      economy = [ "", format("%-16s %10s %10s %12s %14s", "hull", "cost", "bought", "damage/cost", "integrity/cost") ] +
        economics.map { |e|
          format("%-16s %10d %10d %12.3f %14.2f", e[:key], e[:cost], e[:per_budget],
                 e[:damage_per_cost], e[:integrity_per_cost])
        }

      [ header ] + rows + economy + [ "", "wins across the grid, ignoring mirrors:" ] +
        dominance.sort_by { |_, rate| -rate }.map { |hull, rate| format("  %-16s %3d%%", hull.key, rate) }
    end

    private

    def find(attacker, defender_key)
      results.find { |r| r.attacker == attacker && r.defender.key == defender_key }
    end

    def duel(attacker, defender)
      mine = affordable(attacker)
      theirs = affordable(defender)

      wins = (1..@seeds).count do |seed|
        Resolver.new(forces: [ Force.of("attacker", { attacker.combat_unit => mine }),
                               Force.of("defender", { defender.combat_unit => theirs }) ],
                     seed: seed, rounds: @rounds).resolve.won?("attacker")
      end

      Result.new(attacker: attacker, defender: defender,
                 win_rate: (wins * 100.0 / @seeds).round, count: mine, against: theirs)
    end

    def affordable(hull) = [ @budget / hull.build_cost, 1 ].max
  end
end
