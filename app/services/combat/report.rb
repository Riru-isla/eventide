module Combat
  # What happened, in a form a commander can read and a test can assert.
  #
  # Carries the seed it was fought with, so the battle can be replayed exactly rather than
  # taken on trust.
  class Report
    attr_reader :seed, :rounds

    def initialize(seed:, attacker:, defender:, rounds:)
      @seed = seed
      @attacker = attacker
      @defender = defender
      @rounds = rounds
    end

    # Nobody "wins" a battle that ends with both sides still standing — six rounds is a
    # length of engagement, not a fight to the last hull. An attacker that failed to clear
    # the defenders has not taken the ground.
    def outcome
      return :mutual_destruction unless @attacker.any? || @defender.any?
      return :attacker if @defender.standing.empty?
      return :defender if @attacker.standing.empty?

      :stalemate
    end

    def attacker_won? = outcome == :attacker

    def to_h
      {
        seed: @seed,
        outcome: outcome,
        rounds: @rounds,
        attacker: side(@attacker),
        defender: side(@defender)
      }
    end

    private

    def side(force)
      {
        name: force.name,
        survivors: force.survivors,
        casualties: force.casualties,
        losses: force.losses
      }
    end
  end
end
