class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.references :user, null: false, foreign_key: true
      t.references :character, foreign_key: true
      t.string :name
      t.integer :status, null: false, default: 0
      t.integer :ship_q
      t.integer :ship_r
      t.integer :fuel, null: false, default: 10
      t.integer :scrap, null: false, default: 0
      t.string :cargo_sequence
      t.json :discovered_sectors, null: false, default: []
      t.json :researched_upgrades, null: false, default: {}
      t.json :resolved_events, null: false, default: []
      t.integer :draft_step, null: false, default: 1

      t.timestamps
    end
  end
end
