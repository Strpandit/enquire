class NormalizeBlankUsernamesOnAccounts < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE accounts
      SET username = NULL
      WHERE username IS NOT NULL AND btrim(username) = '';
    SQL

    remove_index :accounts, name: "index_accounts_on_lower_username"
    add_index :accounts, "LOWER(username)", unique: true, where: "username IS NOT NULL", name: "index_accounts_on_lower_username"
  end

  def down
    remove_index :accounts, name: "index_accounts_on_lower_username"
    add_index :accounts, "LOWER(username)", unique: true, name: "index_accounts_on_lower_username"
  end
end
