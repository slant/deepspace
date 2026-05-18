class CreateCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :characters do |t|
      t.string :name
      t.string :ship_name
      t.integer :ship_type
      t.datetime :locked_at

      t.timestamps
    end
  end
end
