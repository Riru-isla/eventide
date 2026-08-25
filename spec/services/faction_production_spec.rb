require 'rails_helper'

RSpec.describe FactionProduction, type: :service do
  subject(:production) { described_class.new(galaxy) }

  let(:galaxy) do
    GalaxyGenerator.new(name: "Production", size: "tiny", faction_count: 4, player_configs: []).generate
  end
  let(:faction) { galaxy.npc_factions.by_power.first }

  def rouse!(state = :aware)
    faction.update!(aggression: state)
  end

  describe "who works" do
    it "leaves a faction nobody has provoked entirely alone" do
      expect { production.run! }.not_to change { faction.reload.metal }
      expect(faction.projects).to be_empty
    end

    it "sets a roused faction to work" do
      rouse!

      production.run!

      expect(faction.reload.projects).to be_any
      expect(faction.projects.first.kind).to eq("fortify")
    end

    it "leaves a faction that has already fallen alone" do
      rouse!
      faction.update!(fallen_at_tick: 1)

      production.run!

      expect(faction.reload.projects).to be_empty
    end
  end

  describe "paying for the work" do
    it "charges the whole cost up front, as a build order does" do
      rouse!
      before = faction.metal

      production.run!

      project = faction.reload.projects.first
      expect(faction.metal).to eq(before - (project.defence_gain * described_class::COST_PER_DEFENCE))
      expect(faction.crystal).to eq(faction.metal)
    end

    it "queues nothing it cannot pay for outright" do
      rouse!
      faction.update!(metal: 1, crystal: 1)

      production.run!

      expect(faction.reload.projects).to be_empty
    end
  end

  describe "how much it can do at once" do
    it "works on one garrison per world it runs" do
      rouse!

      production.run!

      expect(faction.reload.projects.count).to eq(faction.build_slots)
    end

    it "starts nothing new while its slots are full" do
      rouse!
      production.run!

      expect { production.run! }.not_to change { faction.reload.projects.count }
    end

    it "works on fewer fronts once a world is taken from it" do
      rouse!
      faction.planets.first.destroy!

      production.run!

      expect(faction.reload.projects.count).to eq(faction.reload.build_slots)
    end
  end

  describe "finishing" do
    it "hardens the garrison when the tick comes round" do
      rouse!
      production.run!
      project = faction.reload.projects.first
      target = project.system
      expected = target.defense_strength + project.defence_gain

      galaxy.update!(current_tick: project.completes_at_tick)
      production.run!

      expect(target.reload.defense_strength).to eq(expected)
      expect(FactionProject.exists?(project.id)).to be(false)
    end

    it "leaves work that has not come round yet alone" do
      rouse!
      production.run!
      project = faction.reload.projects.first

      galaxy.update!(current_tick: project.completes_at_tick - 1)
      production.run!

      expect(FactionProject.exists?(project.id)).to be(true)
    end

    it "works faster the harder the faction is playing" do
      rouse!(:aware)
      slow = faction.build_speed
      rouse!(:total_war)

      expect(faction.reload.build_speed).to be > slow
    end
  end

  describe "what it will not do" do
    it "stops once every garrison is at the ceiling, rather than fortifying forever" do
      # The bound matters: a faction left alone should end up harder, not untouchable.
      rouse!
      faction.systems.update_all(defense_strength: faction.fortification_ceiling)

      production.run!

      expect(faction.reload.projects).to be_empty
    end

    it "never touches its capital, which is already built past the ceiling" do
      rouse!

      production.run!

      expect(faction.reload.projects.map(&:system_id)).not_to include(faction.capital_system_id)
    end
  end

  describe "what it chooses" do
    it "shores up the garrison nearest the ground a commander holds" do
      rouse!
      empire = create(:empire, galaxy: galaxy)
      held = faction.systems.where.not(id: faction.capital_system_id).last
      # A commander sitting on top of one of its systems: the neighbouring garrison is the
      # one under threat, so that is what gets reinforced first.
      beachhead = galaxy.systems.where(npc_faction_id: nil, empire_id: nil).min_by { |s| s.distance_to(held.x, held.y) }
      beachhead.update!(empire: empire)

      production.run!

      chosen = faction.reload.projects.first.system
      nearest = faction.systems.where.not(id: faction.capital_system_id)
                       .where(defense_strength: ...faction.fortification_ceiling)
                       .min_by { |s| s.distance_to(beachhead.x, beachhead.y) }

      expect(chosen.distance_to(beachhead.x, beachhead.y)).to eq(nearest.distance_to(beachhead.x, beachhead.y))
    end

    it "works through whatever is under-built when no commander is anywhere near" do
      rouse!

      production.run!

      expect(faction.reload.projects.first.system.npc_faction_id).to eq(faction.id)
    end
  end
end
