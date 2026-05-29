class AddActivatedHexesToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :activated_hexes, :json, default: [], null: false
  end
end
