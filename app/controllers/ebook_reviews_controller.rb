class EbookReviewsController < ApplicationController
  def create
    attributes = params.expect(review: [ :evidence_id, :candidate_index, :expected_revision ])
    @release = Ebooks::ReviewFact.call(release_id: params.expect(:release_id), evidence_id: attributes[:evidence_id],
      candidate_index: Integer(attributes[:candidate_index], exception: false), expected_revision: Integer(attributes[:expected_revision], exception: false))
    @reviewed_values = Releases::EditorValues.call(release: @release)
    render_evidence
  rescue Releases::RevisionConflict, Ebooks::ReviewFact::InvalidCandidate, Releases::Save::InvalidChanges => error
    @release = Release.find(params.expect(:release_id))
    @evidence_error = error.message
    render_evidence(status: :unprocessable_content)
  end

  private

  def render_evidence(status: :ok)
    @snapshot = Releases::Snapshot.call(release: @release)
    render partial: "releases/evidence_frame", status: status
  end
end
