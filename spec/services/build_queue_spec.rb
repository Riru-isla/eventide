require 'rails_helper'

RSpec.describe BuildQueue, type: :service do
  let(:galaxy) { create(:galaxy, current_tick: 100) }
  let(:empire) { create(:empire, galaxy: galaxy, metal: 100_000, crystal: 100_000) }
  let(:system) { create(:system, galaxy: galaxy) }
  let(:planet) { Planet.create!(empire: empire, system: system, name: "World") }

  before do
    Structure::STARTING_LEVELS.each { |kind, level| planet.structures.create!(kind: kind, level: level) }
  end

  def queue = planet.reload.queue

  describe "#enqueue!" do
    it "creates an order for the next level" do
      order = queue.enqueue!("solar_array")

      expect(order.kind).to eq("solar_array")
      expect(order.target_level).to eq(2)
      expect(order.ticks_required).to be_positive
    end

    it "charges the empire when the order is queued, not when it finishes" do
      cost = Structure.find("solar_array").upgrade_cost(1)

      expect { queue.enqueue!("solar_array") }.to change { empire.reload.metal }.by(-cost[:metal])
    end

    it "starts the first order right away" do
      order = queue.enqueue!("solar_array")

      expect(order.reload.completes_at_tick).to eq(100 + order.ticks_required)
    end

    it "leaves a second order waiting" do
      queue.enqueue!("solar_array")
      second = queue.enqueue!("refinery")

      expect(second.reload.completes_at_tick).to be_nil
    end

    it "stacks repeated upgrades on the highest queued level" do
      queue.enqueue!("solar_array")
      second = queue.enqueue!("solar_array")

      expect(second.target_level).to eq(3)
    end

    it "prices a stacked upgrade from the queued level, not the built one" do
      queue.enqueue!("solar_array")
      before = empire.reload.metal
      queue.enqueue!("solar_array")

      expect(before - empire.reload.metal).to eq(Structure.find("solar_array").upgrade_cost(2)[:metal])
    end

    it "refuses a structure whose prerequisites are unmet" do
      expect { queue.enqueue!("planetary_shield") }
        .to raise_error(described_class::Error, /Shipyard 5/)
    end

    it "allows it once the prerequisites are met" do
      planet.structures.find_by(kind: "shipyard").update!(level: 5)
      empire.technologies.create!(kind: "armor_technology", level: 3)

      expect { queue.enqueue!("planetary_shield") }.to change(BuildOrder, :count).by(1)
    end

    it "refuses an unknown structure" do
      expect { queue.enqueue!("orbital_casino") }.to raise_error(described_class::Error, /unknown/)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { queue.enqueue!("solar_array") }.to raise_error(described_class::Error, /needs/)
    end

    it "does not leave an order behind when it cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { queue.enqueue!("solar_array") rescue nil }.not_to change(BuildOrder, :count)
    end

    it "shortens build time as the Robotics Bay grows" do
      slow = queue.enqueue!("refinery").ticks_required
      BuildOrder.delete_all
      planet.structures.find_by(kind: "robotics_bay").update!(level: 8)

      expect(queue.enqueue!("refinery").ticks_required).to be < slow
    end
  end

  describe "#advance!" do
    it "leaves an order alone before it is due" do
      queue.enqueue!("solar_array")

      queue.advance!

      expect(planet.reload.level_of("solar_array")).to eq(1)
    end

    it "applies an order once its tick arrives" do
      order = queue.enqueue!("solar_array")
      galaxy.update!(current_tick: order.completes_at_tick)

      queue.advance!

      expect(planet.reload.level_of("solar_array")).to eq(2)
      expect(BuildOrder.exists?(order.id)).to be false
    end

    it "starts the next order when one completes" do
      first = queue.enqueue!("solar_array")
      second = queue.enqueue!("refinery")
      galaxy.update!(current_tick: first.completes_at_tick)

      queue.advance!

      expect(second.reload).to be_building
    end

    it "clears the whole queue in one pass when a long gap has passed" do
      first = queue.enqueue!("solar_array")
      queue.enqueue!("refinery")
      galaxy.update!(current_tick: first.completes_at_tick + 10_000)

      queue.advance!

      expect(planet.reload.level_of("solar_array")).to eq(2)
      expect(planet.reload.level_of("refinery")).to eq(1)
      expect(planet.build_orders).to be_empty
    end

    it "chains the next order from when the previous finished, not from now" do
      first = queue.enqueue!("solar_array")
      second = queue.enqueue!("refinery")
      galaxy.update!(current_tick: first.completes_at_tick)

      queue.advance!

      expect(second.reload.completes_at_tick).to eq(first.completes_at_tick + second.ticks_required)
    end

    it "does nothing on an empty queue" do
      expect { queue.advance! }.not_to raise_error
    end
  end

  describe "#current and #queued_level_for" do
    it "reports the order under way" do
      queue.enqueue!("solar_array")

      expect(queue.current.kind).to eq("solar_array")
    end

    it "is nil when nothing is queued" do
      expect(queue.current).to be_nil
      expect(queue.queued_level_for("solar_array")).to be_nil
    end

    it "reports the highest queued level for a structure" do
      queue.enqueue!("solar_array")
      queue.enqueue!("solar_array")

      expect(queue.queued_level_for("solar_array")).to eq(3)
    end
  end
end
