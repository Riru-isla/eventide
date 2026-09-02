module Combat
  # What happened, in a form a commander can read and a test can assert.
  #
  # Carries the seed it was fought with, so the battle can be replayed exactly rather than
  # taken on trust.
  class Report
    attr_reader :seed, :rounds

    def initialize(seed:, forces:, rounds:)
      @seed = seed
      @forces = forces
      @rounds = rounds
    end

    # The allegiances that still have something in the field.
    def standing
      @forces.select(&:any?).map(&:allegiance).uniq
    end

    # The side that holds the field, or nothing if several do or none do. Six rounds is a
    # length of engagement rather than a fight to the last hull, so an attacker who failed
    # to clear the defenders has not taken the ground.
    def victor
      standing.size == 1 ? standing.first : nil
    end

    def won?(allegiance) = victor == allegiance

    def outcome
      return :annihilation if standing.empty?
      return :stalemate if standing.size > 1

      :decided
    end

    def to_h
      {
        seed: @seed,
        outcome: outcome,
        victor: victor,
        rounds: @rounds,
        forces: @forces.to_h { |force| [ force.name, side(force) ] }
      }
    end

    private

    def side(force)
      {
        allegiance: force.allegiance,
        survivors: force.survivors,
        casualties: force.casualties,
        losses: force.losses
      }
    end
  end
end
