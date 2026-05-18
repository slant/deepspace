class CreateOfficers < ActiveRecord::Migration[8.1]
  def change
    create_table :officers do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.integer :title, null: false, default: 0
      t.string :specialty
      t.string :attribute_a
      t.string :attribute_b
      t.integer :position, null: false

      t.timestamps
    end

    add_index :officers, [ :character_id, :position ], unique: true
  end
end
