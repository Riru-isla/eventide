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

    # What this stack pulls of the incoming fire.
    def weight = alive * @unit.draw

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

    # A shot works outward-in. Whatever a layer cannot absorb carries on to the next,
    # converted at that layer's rate — so a weapon poor against shields still punches
    # through a *thin* one, while a genuinely shield-heavy hull stops it dead.
    #
    # Two models were tried and measured before this one. Letting a shot spend a shared
    # budget across all three layers punished specialisation: an anti-armour gun had to pay
    # its way through shields at its own worst rate, so a mediocre generalist beat it even
    # against armour, killing 20 of 20 where the specialist killed 0.2. Restricting a shot
    # to a single layer produced clean counters but broke the other end — fifteen
    # battleships killed *zero* corvettes, because each 800-damage shot was spent stripping
    # ten points of shield.
    #
    # Carrying the excess gives both: specialists still counter, and big guns still kill
    # small ships, wastefully.
    def absorb(layers, damage)
      carried = nil
      previous = nil

      LAYERS.each_with_index do |layer, index|
        rate = damage.fetch(layer).to_f
        # A weapon with nothing at all to say to a layer never gets past it.
        break if rate <= 0

        incoming = carried.nil? ? rate : (carried * rate / previous)
        previous = rate

        dealt = [ incoming, layers[index] ].min
        layers[index] -= dealt
        carried = incoming - dealt
        break if carried <= 0
      end
    end

    def destroy(index)
      @wounded.delete_at(index)
      @losses += 1
    end
  end
end
