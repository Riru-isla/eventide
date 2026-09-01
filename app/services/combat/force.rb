module Combat
  # One side of a battle: its stacks, and what it has left.
  class Force
    attr_reader :name, :stacks

    def initialize(name:, stacks:)
      @name = name
      @stacks = stacks
    end

    # Built from { unit => count }, dropping anything that brought nobody.
    def self.of(name, composition)
      new(name: name, stacks: composition.filter_map { |unit, count|
        Stack.new(unit: unit, count: count) if count.to_i.positive?
      })
    end

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
