class CreateBusinessProfileCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :business_profile_categories do |t|
      t.references :category, null: false, foreign_key: true
      t.references :business_profile, null: false, foreign_key: true

      t.timestamps
    end

    add_index :business_profile_categories, [:business_profile_id, :category_id], unique: true
  end
end
