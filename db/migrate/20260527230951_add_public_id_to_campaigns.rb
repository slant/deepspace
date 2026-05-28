class AddPublicIdToCampaigns < ActiveRecord::Migration[8.1]
  def up
    add_column :campaigns, :public_id, :string

    # Backfill any existing campaigns
    Campaign.find_each do |c|
      c.update_column(:public_id, generate_unique_public_id)
    end

    change_column_null :campaigns, :public_id, false
    add_index :campaigns, :public_id, unique: true
  end

  def down
    remove_column :campaigns, :public_id
  end

  private

  def generate_unique_public_id
    loop do
      id = SecureRandom.alphanumeric(4)
      break id unless Campaign.exists?(public_id: id)
    end
  end
end
