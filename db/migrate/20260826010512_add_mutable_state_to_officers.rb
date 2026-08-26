class AddMutableStateToOfficers < ActiveRecord::Migration[8.1]
  def change
    add_column :officers, :bonus_attributes, :json, default: [], null: false
    add_column :officers, :dead, :boolean, default: false, null: false
    add_column :officers, :title_override, :string
  end
end
