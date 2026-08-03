class AddAuthToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :username, :string
    add_index :players, :username, unique: true
    add_column :players, :password_digest, :string
  end
end
