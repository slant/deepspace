class AddPlanetSpritesToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :planet_sprites, :json, default: {}, null: false
  end
end
