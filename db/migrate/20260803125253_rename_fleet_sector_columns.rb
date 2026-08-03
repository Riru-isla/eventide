class RenameFleetSectorColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :fleets, :origin_sector, :origin_sector_id
    rename_column :fleets, :target_sector, :target_sector_id
  end
end
