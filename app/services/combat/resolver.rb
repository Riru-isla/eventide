module Combat
  # Resolves one battle between any number of contingents. A plain object: no database, no
  # galaxy, no Rails.
  #
  # Seeded on purpose. The same forces and seed fight the same battle every time, which
  # makes outcomes assertable in a test rather than only statistically checkable, and lets a
  # stored report be re-derived instead of merely trusted.
  #
  # Every unit fires its own shot, which is what gives luck the right shape: a handful of
  # ships is genuinely swingy, while at two thousand a side the better fleet wins and only
  # the margin varies. That falls out of the number of dice rather than a tuned constant.
  class Resolver
    ROUNDS = 6

    def initialize(forces:, seed: nil, rounds: ROUNDS)
      @forces = forces
      @seed = seed || Random.new_seed
      @rounds = rounds
      @rng = Random.new(@seed)
    end

    def resolve
      rounds = []

      @rounds.times do |number|
        break unless contested?

        rounds << fight_round(number + 1)
      end

      Report.new(seed: @seed, forces: @forces, rounds: rounds)
    end

    private

    # A fight continues while two sides that will shoot at each other are both still there.
    # Allies left alone in the field have nothing to resolve.
    def contested?
      @forces.select(&:any?).map(&:allegiance).uniq.size > 1
    end

    # Everyone fires before anyone takes their losses, so a contingent that is wiped out
    # still gets its shots away. Mutual destruction has to be possible, or defending is free.
    def fight_round(number)
      volleys = @forces.map { |force| [ force, volley(force) ] }
      before = @forces.to_h { |force| [ force.name, force.alive ] }

      volleys.each { |force, shots| deliver(shots, enemies_of(force)) }
      @forces.each(&:regenerate!)

      { number: number, losses: @forces.to_h { |force| [ force.name, before[force.name] - force.alive ] } }
    end

    def enemies_of(force)
      @forces.reject { |other| other.allied_with?(force) }
    end

    # Shots as [profile, how many], not one entry per shot: a million-ship fleet fires a
    # million times, and materialising that as an array would cost more than the battle.
    def volley(force)
      force.standing.map { |stack| [ stack.unit.damage, stack.alive ] }
    end

    # Fire spreads across everything hostile, so a coalition shares what is coming at it
    # rather than each contingent absorbing its own share.
    def deliver(volley, enemies)
      targets = enemies.flat_map(&:stacks)
      weight = targets.sum(&:weight)

      volley.each do |damage, count|
        count.times do
          break if weight <= 0

          target = pick(targets, weight)
          weight -= target.unit.draw if target.take(damage, @rng)
        end
      end
    end

    # Weighted by what each hull draws, not by how many of them there are. Uniform targeting
    # meant a heavy ship soaked only its own share, so ten of them screening a hundred
    # corvettes saved exactly one corvette and came through untouched.
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
