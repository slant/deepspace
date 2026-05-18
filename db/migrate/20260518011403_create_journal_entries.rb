class CreateJournalEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entries do |t|
      t.references :campaign, null: false, foreign_key: true
      t.text :body
      t.string :entry_type
      t.json :metadata

      t.timestamps
    end
  end
end
