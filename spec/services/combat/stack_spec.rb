require 'rails_helper'

RSpec.describe Combat::Stack, type: :service do
  def unit(shield: 10, armour: 10, hull: 40, damage: { shield: 50, armour: 50, hull: 50 }, signature: 1)
    Combat::Unit.new(key: :test, name: "Test", category: "ship", signature: signature,
                     shield: shield, armour: armour, hull: hull, damage: damage)
  end

  let(:rng) { Random.new(1) }
  let(:killing_blow) { { shield: 1_000, armour: 1_000, hull: 1_000 } }

  def kill!(stack)
    stack.take(killing_blow, rng)
  end
  let(:scratch) { { shield: 5, armour: 5, hull: 5 } }

  describe "spreading damage" do
    it "wounds a different unit each time rather than finishing one off" do
      # Five hundred shots into ten thousand corvettes should wound five hundred of them,
      # not destroy a handful. Those are completely different battles.
      stack = described_class.new(unit: unit, count: 10_000)

      500.times { stack.take(scratch, rng) }

      expect(stack.losses).to be_zero
      expect(stack.alive).to eq(10_000)
    end

    it "keeps only the wounded in memory, so fleet size does not cost anything" do
      stack = described_class.new(unit: unit, count: 1_000_000)

      expect { 100.times { stack.take(scratch, rng) } }.not_to raise_error
      expect(stack.alive).to eq(1_000_000)
    end
  end

  describe "layers" do
    it "carries what a layer cannot absorb through to the next" do
      # Thirty across three layers of ten: one shot of thirty gets all the way through,
      # which is what lets a big gun kill a small ship at all.
      stack = described_class.new(unit: unit(shield: 10, armour: 10, hull: 10), count: 1)

      stack.take({ shield: 30, armour: 30, hull: 30 }, rng)

      expect(stack.alive).to be_zero
    end

    it "converts the overflow at the next layer's rate, not its own" do
      # A gun that is feeble against hull does not become strong just because it tore
      # through the shield in front of it.
      tough = described_class.new(unit: unit(shield: 10, armour: 0, hull: 200), count: 1)

      tough.take({ shield: 500, armour: 5, hull: 5 }, rng)

      expect(tough.alive).to eq(1)
    end

    it "leaves a unit standing when the shot runs out inside a layer" do
      stack = described_class.new(unit: unit(shield: 100, armour: 0, hull: 10), count: 1)

      stack.take({ shield: 30, armour: 30, hull: 30 }, rng)

      expect(stack.alive).to eq(1)
    end

    it "cannot get past a layer it does no damage to at all" do
      # A weapon with nothing to say to shields never reaches what is behind them. That is
      # what makes a shield-heavy hull a hard counter rather than merely a tough one.
      stack = described_class.new(unit: unit(shield: 500, armour: 0, hull: 10), count: 1)

      5.times { stack.take({ shield: 0, armour: 900, hull: 900 }, rng) if stack.any? }

      expect(stack.alive).to eq(1)
    end

    it "passes straight through a layer that is already gone" do
      stack = described_class.new(unit: unit(shield: 0, armour: 0, hull: 30), count: 1)

      stack.take({ shield: 50, armour: 50, hull: 50 }, rng)

      expect(stack.alive).to be_zero
    end
  end

  describe "regeneration" do
    it "recharges part of a shield between rounds, so a trickle cannot accumulate" do
      # A shot that a shield absorbs, followed by a recharge larger than what got through,
      # never adds up to anything.
      stack = described_class.new(unit: unit(shield: 400, armour: 0, hull: 10), count: 1)

      6.times do
        stack.take({ shield: 50, armour: 50, hull: 50 }, rng)
        stack.regenerate!
      end

      expect(stack.alive).to eq(1)
    end

    it "recharges only part of it, so a heavy enough volley still wears one down" do
      # At full recharge a weapon poor against shields could never get through one at all,
      # and specialised guns were useless outright.
      stack = described_class.new(unit: unit(shield: 400, armour: 0, hull: 10), count: 1)

      6.times do
        4.times { stack.take({ shield: 100, armour: 100, hull: 100 }, rng) if stack.any? }
        stack.regenerate!
      end

      expect(stack.alive).to be_zero
    end

    it "does not undo damage that already reached the hull" do
      # The shield comes back each round; the hull it was covering does not.
      stack = described_class.new(unit: unit(shield: 10, armour: 0, hull: 100), count: 1)

      stack.take({ shield: 60, armour: 60, hull: 60 }, rng)
      stack.regenerate!
      expect(stack.alive).to eq(1)

      stack.take({ shield: 60, armour: 60, hull: 60 }, rng)

      expect(stack.alive).to be_zero
    end
  end

  describe "counting" do
    it "reports what is left and what was lost" do
      stack = described_class.new(unit: unit, count: 1)

      expect(stack).to be_any
      expect(stack.losses).to be_zero

      kill!(stack)

      expect(stack.alive).to be_zero
      expect(stack.losses).to eq(1)
    end

    it "draws fire in proportion to its signature, not its head count" do
      light = described_class.new(unit: unit(signature: 1), count: 10)
      heavy = described_class.new(unit: unit(signature: 10), count: 10)

      expect(heavy.weight).to eq(light.weight * 10)
    end

    it "says when a stack is gone" do
      stack = described_class.new(unit: unit, count: 1)
      kill!(stack)

      expect(stack).not_to be_any
    end
  end
end
