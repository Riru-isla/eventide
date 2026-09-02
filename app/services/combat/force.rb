module Combat
  # One contingent in a battle: its stacks, what it has left, and whose side it is on.
  #
  # `allegiance` is what makes a battle more than two-sided. Anyone sharing it fights
  # alongside you and is never shot at; everyone else is a target. Three commanders storming
  # one faction is three forces sharing an allegiance, and a planet defended by its owner,
  # their turrets and an ally who happened to be in orbit is the same shape. A free-for-all
  # is simply three allegiances.
  class Force
    attr_reader :name, :allegiance, :stacks

    def initialize(name:, stacks:, allegiance: nil)
      @name = name
      @allegiance = allegiance || name
      @stacks = stacks
    end

    # Built from { unit => count }, dropping anything that brought nobody. Without an
    # allegiance a contingent fights for itself, which is what a two-sided battle wants.
    def self.of(name, composition, allegiance: nil)
      new(name: name, allegiance: allegiance,
          stacks: composition.filter_map { |unit, count|
            Stack.new(unit: unit, count: count) if count.to_i.positive?
          })
    end

    def allied_with?(other) = allegiance == other.allegiance

    def standing = @stacks.select(&:any?)

    def any? = standing.any?

    def alive = @stacks.sum(&:alive)

    def losses = @stacks.sum(&:losses)

    # Everything still able to shoot, once each. Immobile units fire from where they stand,
    # so nothing here distinguishes them — that decision was made before the battle, by
    # whether they were brought at all.
    def each_shot
      standing.each do |stack|
        stack.alive.times { yield stack.unit.damage }
      end
    end

    def regenerate!
      @stacks.each(&:regenerate!)
    end

    def casualties
      @stacks.filter_map { |stack| [ stack.unit.key, stack.losses ] if stack.losses.positive? }.to_h
    end

    def survivors
      @stacks.filter_map { |stack| [ stack.unit.key, stack.alive ] if stack.any? }.to_h
    end
  end
end
