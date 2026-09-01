module Combat
  # A group of identical units on one side of a battle.
  #
  # Damage has to *spread* rather than concentrate: five hundred shots into ten thousand
  # corvettes should wound five hundred of them, not destroy a handful outright. Those are
  # completely different battles, and only the first is what actually happens.
  #
  # So intact units are only ever a count, and one is moved into `wounded` as it is hit.
  # Memory is proportional to shots fired rather than to fleet size, which is what makes a
  # battle of a million ships possible at all.
  class Stack
    LAYERS = %i[shield armour hull].freeze

    attr_reader :unit, :losses

    def initialize(unit:, count:)
      @unit = unit
      @intact = count
      @wounded = []
      @losses = 0
    end

    def alive = @intact + @wounded.size

    def any? = alive.positive?

    # Picks a unit uniformly from everything in this stack still standing and puts one shot
    # into it. `damage` is the *shooter's* profile — what it does to each layer — not the
    # target's. Returns true when the shot destroyed something, so the caller can keep a
    # running count without re-summing every stack for every shot.
    def take(damage, rng)
      index = rng.rand(alive)

      if index < @intact
        @intact -= 1
        @wounded << [ @unit.shield, @unit.armour, @unit.hull ]
        index = @wounded.size - 1
      else
        index -= @intact
      end

      absorb(@wounded[index], damage)
      return false if @wounded[index][2].positive?

      destroy(index)
      true
    end

    # Shields come back between rounds. That is what stops a trickle of small hits ever
    # getting through a heavy hull, while a volley big enough to outpace regeneration still
    # goes straight through — the threshold is a matter of rate, not a rule.
    def regenerate!
      @wounded.each { |layers| layers[0] = @unit.shield }
    end

    private

    # One shot spends itself across shield, then armour, then hull. `spent` tracks how much
    # of the shot is used up as a fraction, so a layer that absorbs everything ends it and a
    # layer that cannot carries the rest on at the *next* layer's rate. With all three
    # figures equal — which is every unit today — this is plain sequential depletion.
    def absorb(layers, damage)
      spent = 0.0

      LAYERS.each_with_index do |layer, index|
        break if spent >= 1.0

        rate = damage.fetch(layer).to_f
        next if rate <= 0

        available = rate * (1.0 - spent)
        dealt = [ available, layers[index] ].min
        layers[index] -= dealt
        spent += dealt / rate
      end
    end

    def destroy(index)
      @wounded.delete_at(index)
      @losses += 1
    end
  end
end
