class ConfirmExistingUsers < ActiveRecord::Migration[8.1]
  # Accounts created before email confirmation existed must not be locked out when an operator turns it on.
  def up
    execute "UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL"
  end

  def down
  end
end
