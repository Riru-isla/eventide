# Galaxies stop being a single hardcoded world and become something an admin creates from
# a form, so the knobs that generation reads have to live on the record rather than being
# derived from `size` alone.
class AddGalaxySettingsAndAdmins < ActiveRecord::Migration[8.1]
  def change
    change_table :galaxies, bulk: true do |t|
      # How many NPC factions to build. Sectors are this plus one, for the players'.
      t.integer :faction_count, null: false, default: 4
      t.string :victory_condition, null: false, default: "reach_the_core"
      # Always 1 for now. Stored so the field on the form means something later.
      t.integer :team_count, null: false, default: 1
      # Multipliers on how hard garrisons hit and how readily factions notice players.
      t.string :threat_level, null: false, default: "standard"
      t.string :awareness_level, null: false, default: "standard"
    end

    # How readily this faction reacts to a neighbour falling. Set at generation from the
    # galaxy's awareness level; read by the awakening step.
    add_column :npc_factions, :awareness, :integer, null: false, default: 50

    # Not a role system — one flag, so the generate and inspect controls can be hidden
    # from the people who are only here to play.
    add_column :users, :admin, :boolean, null: false, default: false
  end
end
