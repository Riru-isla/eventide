# Player already validates one commander per account per galaxy, but a validation is a
# read-then-write: two people joining the same galaxy in the same instant can both pass it
# and both insert. Seven colleagues clicking Join at once is exactly that shape.
class EnforceOnePlayerPerGalaxy < ActiveRecord::Migration[8.1]
  def change
    add_index :players, [ :user_id, :galaxy_id ], unique: true
  end
end
