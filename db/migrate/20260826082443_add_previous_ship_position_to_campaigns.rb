class AddPreviousShipPositionToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :previous_ship_q, :integer
    add_column :campaigns, :previous_ship_r, :integer
  end
end
