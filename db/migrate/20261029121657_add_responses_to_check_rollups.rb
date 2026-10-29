class AddResponsesToCheckRollups < ActiveRecord::Migration[8.1]
  def change
    add_column :check_rollups, :responses, :integer, null: false, default: 0
  end
end
