class RenameHomeSectorToHomeSectorIdInEmpires < ActiveRecord::Migration[8.1]
  def change
    rename_column :empires, :home_sector, :home_sector_id
  end
end
