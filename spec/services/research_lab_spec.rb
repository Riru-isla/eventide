require 'rails_helper'

RSpec.describe ResearchLab, type: :service do
  let(:galaxy) { create(:galaxy, current_tick: 200) }
  let(:empire) { create(:empire, galaxy: galaxy, metal: 100_000, crystal: 100_000) }
  let(:system) { create(:system, galaxy: galaxy) }
  let!(:planet) { Planet.create!(empire: empire, system: system, name: "World") }

  def set_center(level)
    planet.structures.find_or_create_by!(kind: "research_center") { |s| s.level = 0 }.update!(level: level)
    empire.reload
  end

  def lab = empire.reload.research

  before { set_center(1) }

  describe "requirements" do
    it "allows a technology whose prerequisites are met" do
      expect(lab).to be_available(Technology.find("extraction_technology"))
    end

    it "locks a technology when the Research Center is too small" do
      missing = lab.unmet_requirements(Technology.find("weapons_technology"))

      expect(missing).to eq([ "Research Center 2" ])
    end

    it "locks a technology when a prerequisite technology is missing" do
      set_center(3)

      expect(lab.unmet_requirements(Technology.find("laser_technology")))
        .to contain_exactly("Energy Technology 2", "Weapons Technology 2")
    end

    it "unlocks once the prerequisites are researched" do
      set_center(3)
      empire.technologies.create!(kind: "energy_technology", level: 2)
      empire.technologies.create!(kind: "weapons_technology", level: 2)

      expect(lab).to be_available(Technology.find("laser_technology"))
    end
  end

  describe "speed" do
    it "is unmodified at Research Center level 1" do
      expect(lab.speed).to eq(1.0)
    end

    it "improves with a bigger Research Center" do
      set_center(4)

      expect(lab.speed).to be_within(0.001).of(0.7)
    end

    it "never goes below the floor" do
      set_center(100)

      expect(lab.speed).to eq(Technology::MINIMUM_RESEARCH_SPEED)
    end
  end

  describe "#start!" do
    it "charges the empire and starts the project" do
      cost = Technology.find("extraction_technology").research_cost(0)

      expect { lab.start!("extraction_technology") }
        .to change { empire.reload.metal }.by(-cost[:metal])
        .and change(ResearchOrder, :count).by(1)

      order = empire.reload.research_order
      expect(order.target_level).to eq(1)
      expect(order.completes_at_tick).to eq(200 + order.ticks_required)
    end

    it "refuses a second project while one is under way" do
      lab.start!("extraction_technology")

      expect { lab.start!("energy_technology") }.to raise_error(described_class::Error, /already researching/)
    end

    it "refuses a locked technology and names what is missing" do
      expect { lab.start!("laser_technology") }
        .to raise_error(described_class::Error, /Research Center 3/)
    end

    it "refuses an unknown technology" do
      expect { lab.start!("warp_theory") }.to raise_error(described_class::Error, /unknown/)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { lab.start!("extraction_technology") }.to raise_error(described_class::Error, /needs/)
    end

    it "leaves no order behind when it cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { lab.start!("extraction_technology") rescue nil }.not_to change(ResearchOrder, :count)
    end

    it "prices the next level from what is already researched" do
      empire.technologies.create!(kind: "extraction_technology", level: 2)
      cost = Technology.find("extraction_technology").research_cost(2)

      expect { lab.start!("extraction_technology") }.to change { empire.reload.metal }.by(-cost[:metal])
    end
  end

  describe "#advance!" do
    it "leaves a project alone before it is due" do
      lab.start!("extraction_technology")

      lab.advance!

      expect(empire.reload.technology_level("extraction_technology")).to eq(0)
    end

    it "applies the project once its tick arrives" do
      order = lab.start!("extraction_technology")
      galaxy.update!(current_tick: order.completes_at_tick)

      empire.reload.research.advance!

      expect(empire.reload.technology_level("extraction_technology")).to eq(1)
      expect(ResearchOrder.count).to eq(0)
    end

    it "frees the empire to start something else" do
      order = lab.start!("extraction_technology")
      galaxy.update!(current_tick: order.completes_at_tick)
      empire.reload.research.advance!

      expect { empire.reload.research.start!("energy_technology") }.not_to raise_error
    end

    it "does nothing when there is no project" do
      expect { lab.advance! }.not_to raise_error
    end
  end

  describe "without a planet" do
    it "reports no Research Center and locks everything" do
      planet.destroy!

      expect(empire.reload.research.center_level).to eq(0)
      expect(empire.research.unmet_requirements(Technology.find("extraction_technology")))
        .to eq([ "Research Center 1" ])
    end
  end
end
