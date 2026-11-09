class AddReleaseSearchText < ActiveRecord::Migration[8.1]
  def up
    add_column :releases, :search_text, :text, null: false, default: ''
    connection.select_all('SELECT id, title, author FROM releases').each do |row|
      text = row.values_at('title', 'author').compact.join(' ').unicode_normalize(:nfkd).gsub(/\p{M}/, '').downcase.squish
      execute "UPDATE releases SET search_text = #{connection.quote(text)} WHERE id = #{connection.quote(row.fetch('id'))}"
    end
  end

  def down
    remove_column :releases, :search_text
  end
end
