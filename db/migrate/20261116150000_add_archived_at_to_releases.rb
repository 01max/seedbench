class AddArchivedAtToReleases < ActiveRecord::Migration[8.1]
  def change
    add_column :releases, :archived_at, :datetime
  end
end
