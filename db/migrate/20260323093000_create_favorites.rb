class CreateFavorites < ActiveRecord::Migration[8.0]
  def change
    create_table :favorites do |t|
      t.references :account, null: false, foreign_key: true
      t.references :business_profile, null: false, foreign_key: true

      t.timestamps
    end

    add_index :favorites, [ :account_id, :business_profile_id ], unique: true
  end
end
