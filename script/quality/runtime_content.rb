require 'digest'

module RuntimeContent
  def self.prepare(release)
    release.reload
    proposal = Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'bbcode')
    path = Rails.application.config.x.storage.fetch(:scratch).join('runtime-content-proposal.json')
    path.write(JSON.generate(id: proposal.id, sha256: Digest::SHA256.hexdigest(proposal.bodies.fetch('bbcode'))))
  end

  def self.verify(release)
    path = Rails.application.config.x.storage.fetch(:scratch).join('runtime-content-proposal.json')
    saved = JSON.parse(path.read)
    proposal = release.content_proposals.find(saved.fetch('id'))
    abort 'Content proposal changed across recreation' unless Digest::SHA256.hexdigest(proposal.bodies.fetch('bbcode')) == saved.fetch('sha256')
    current = release.content_revisions.where(kind: 'bbcode').order(:number).last
    abort 'An unaccepted proposal replaced human text' unless current.body == 'Preserved human content' && current.id == proposal.bases.fetch('bbcode')
    abort 'Proposal lost its policy provenance' unless proposal.dependencies.dig('bbcode', 'policy_version') == Providers::C411::EbookContent::VERSION
    puts 'Unaccepted content proposal, dependency provenance and full human text survived container recreation.'
  end
end
