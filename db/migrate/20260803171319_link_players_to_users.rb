class LinkPlayersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :user, null: false, foreign_key: true
    remove_index :players, :username if index_exists?(:players, :username)
    remove_column :players, :username, :string
    remove_column :players, :password_digest, :string
  end
end
