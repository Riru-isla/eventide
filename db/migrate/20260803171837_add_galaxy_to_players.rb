class AddGalaxyToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :galaxy, null: false, foreign_key: true
  end
end
