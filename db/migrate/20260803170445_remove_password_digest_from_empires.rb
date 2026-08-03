class RemovePasswordDigestFromEmpires < ActiveRecord::Migration[8.1]
  def change
    remove_column :empires, :password_digest, :string
  end
end
