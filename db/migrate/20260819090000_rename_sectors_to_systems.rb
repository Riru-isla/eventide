# "Sector" is being freed up to mean a large region of the galaxy holding many of these,
# which is both the conventional sci-fi meaning and how the galaxy generation is designed.
# What used to be a Sector — one coordinate, one planet, one place a fleet flies to — is a
# System, which also leaves room for it to hold several bodies later.
class RenameSectorsToSystems < ActiveRecord::Migration[8.1]
  def change
    rename_table :sectors, :systems

    rename_column :empires, :home_sector_id, :home_system_id
    rename_column :fleets, :origin_sector_id, :origin_system_id
    rename_column :fleets, :target_sector_id, :target_system_id
    rename_column :npc_factions, :capital_sector_id, :capital_system_id
    rename_column :planets, :sector_id, :system_id
  end
end
