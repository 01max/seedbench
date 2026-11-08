# == Schema Information
#
# Table name: duplicate_decisions
#
#  id                 :integer          not null, primary key
#  actor              :string           not null
#  candidate_key      :string           not null
#  decision           :string           not null
#  reason             :text
#  reviewed_at        :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  duplicate_check_id :bigint           not null
#  release_id         :integer          not null
#
# Indexes
#
#  idx_on_duplicate_check_id_candidate_key_eadb0be4da  (duplicate_check_id,candidate_key) UNIQUE
#  index_duplicate_decisions_on_release_id             (release_id)
#  index_duplicate_decisions_on_release_id_and_id      (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [release_id, duplicate_check_id]  ([release_id, duplicate_check_id] => duplicate_checks[release_id, id])
#  release_id                        (release_id => releases.id)
#
class DuplicateDecision < ApplicationRecord
  belongs_to :release
  belongs_to :duplicate_check, foreign_key: [ :release_id, :duplicate_check_id ], primary_key: [ :release_id, :id ], inverse_of: :duplicate_decisions
  attr_readonly :release_id, :duplicate_check_id, :candidate_key, :decision, :reason, :actor, :reviewed_at
end
