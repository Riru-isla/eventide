class AddMissionsToFleets < ActiveRecord::Migration[8.1]
  def change
    # A fleet now has an errand rather than being implicitly an attack, and can carry
    # resources while it runs it.
    add_column :fleets, :mission, :string, null: false, default: "attack"
    add_column :fleets, :cargo, :json, default: {}

    add_index :fleets, :status
  end
end
