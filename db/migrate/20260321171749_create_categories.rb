class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name

      t.timestamps
    end

    add_index :categories, "LOWER(name)", unique: true, name: "index_categories_on_lower_name"
  end
end
