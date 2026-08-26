class AddFatigueMarksToOfficers < ActiveRecord::Migration[8.1]
  def change
    add_column :officers, :fatigue_marks, :integer, default: 0, null: false
  end
end
