class AddCrewToEmpires < ActiveRecord::Migration[8.1]
  def change
    # Crew is a third stored resource alongside metal and crystal: trained at the Pilot
    # Academy, held in Crew Quarters, and spent when a hull is laid down.
    add_column :empires, :crew, :integer, null: false, default: 0
  end
end
