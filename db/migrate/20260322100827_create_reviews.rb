class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :account, null: false, foreign_key: true
      t.references :business_profile, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment

      t.timestamps
    end

    add_index :reviews, [:account_id, :business_profile_id], unique: true
  end
end
