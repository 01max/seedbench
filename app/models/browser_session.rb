# == Schema Information
#
# Table name: sessions
#
#  id         :integer          not null, primary key
#  data       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  session_id :string           not null
#
# Indexes
#
#  index_sessions_on_created_at  (created_at)
#  index_sessions_on_session_id  (session_id) UNIQUE
#  index_sessions_on_updated_at  (updated_at)
#
class BrowserSession < ActiveRecord::SessionStore::Session
  self.table_name = "sessions"
  self.serializer = :json

  def self.find_by_session_id(session_id)
    where(created_at: 12.hours.ago..).find_by(session_id: session_id)
  end
end
