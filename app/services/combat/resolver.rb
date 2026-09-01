module Combat
  # Resolves one battle. A plain object: no database, no galaxy, no Rails.
  #
  # Seeded on purpose. The same forces and the same seed give the same battle every time,
  # which makes an outcome assertable in a test rather than only statistically checkable,
  # and lets a stored report be re-derived exactly rather than merely trusted.
  #
  # Every unit fires its own shot, which is what gives luck the right shape: a handful of
  # ships is genuinely swingy, while at two thousand a side the better fleet wins and only
  # the margin varies. That falls out of the number of dice rather than a tuned constant.
  class Resolver
    ROUNDS = 6

    def initialize(attacker:, defender:, seed: nil, rounds: ROUNDS)
      @attacker = attacker
      @defender = defender
      @seed = seed || Random.new_seed
      @rounds = rounds
      @rng = Random.new(@seed)
    end

    def resolve
      rounds = []

      @rounds.times do |number|
        break unless @attacker.any? && @defender.any?

        rounds << fight_round(number + 1)
      end

      Report.new(seed: @seed, attacker: @attacker, defender: @defender, rounds: rounds)
    end

    private

    # Both sides fire before either takes its losses, so a fleet that is wiped out still
    # gets its shots away. Mutual destruction has to be possible, or defending is free.
    def fight_round(number)
      at_defender = volley(@attacker)
      at_attacker = volley(@defender)
      before = { attacker: @attacker.alive, defender: @defender.alive }

      deliver(at_defender, @defender)
      deliver(at_attacker, @attacker)

      @attacker.regenerate!
      @defender.regenerate!

      { number: number,
        attacker_lost: before[:attacker] - @attacker.alive,
        defender_lost: before[:defender] - @defender.alive }
    end

    # Shots as [profile, how many], not one entry per shot: a million-ship fleet fires a
    # million times, and materialising that as an array would cost more memory than the
    # battle is worth.
    def volley(force)
      force.standing.map { |stack| [ stack.unit.damage, stack.alive ] }
    end

    def deliver(volley, force)
      targets = force.stacks
      weight = targets.sum(&:weight)

      volley.each do |damage, count|
        count.times do
          break if weight <= 0

          target = pick(targets, weight)
          weight -= target.unit.draw if target.take(damage, @rng)
        end
      end
    end

    # Weighted by what each hull draws, not by how many of them there are. Uniform
    # targeting meant a heavy ship soaked only its own share, so bringing ten of them to
    # screen a hundred corvettes saved exactly one corvette — the tanks survived untouched
    # and protected nobody, which makes a defensive hull pointless in a shared fleet.
    def pick(targets, weight)
      roll = @rng.rand(weight)

      # `weight` is kept equal to what is still standing, so the roll always lands.
      targets.each do |stack|
        return stack if roll < stack.weight

        roll -= stack.weight
      end
    end
  end
end
