# Two more things chosen when a session is created rather than baked into the code: what
# the galaxy does while nobody is pushing it, and what becomes of a faction once its
# capital falls.
class AddStressAndFallenSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :galaxies, bulk: true do |t|
      # Whether anything escalates without a commander provoking it.
      t.string :stress_level, null: false, default: "chill"
      # What happens to a beaten faction's remaining territory.
      t.string :fallen_outcome, null: false, default: "decay"
    end
  end
end
