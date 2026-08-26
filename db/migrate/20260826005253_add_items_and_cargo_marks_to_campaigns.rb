class AddItemsAndCargoMarksToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :items, :json, default: [], null: false
    add_column :campaigns, :cargo_marks, :json, default: {}, null: false
  end
end
