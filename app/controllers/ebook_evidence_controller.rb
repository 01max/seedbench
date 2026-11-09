class EbookEvidenceController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_evidence
  end

  def create
    attributes = params.expect(inspection: [ :kind, :expected_revision, :isbn ])
    @release = Release.find(params.expect(:release_id))
    Ebooks::Action.call(release_id: @release.id, kind: attributes[:kind], isbn: attributes[:isbn],
      expected_revision: Integer(attributes[:expected_revision], exception: false))
    @evidence_notice = t("ebooks.queued")
    render_evidence
  rescue Releases::RevisionConflict, Ebooks::Action::UnknownAction, Ebooks::EditionRecord::InvalidIsbn => error
    @evidence_error = error.message
    render_evidence(status: :unprocessable_content)
  end

  private

  def render_evidence(status: :ok)
    @release.reload
    @snapshot = Releases::Snapshot.call(release: @release)
    render partial: "releases/evidence_frame", status: status
  end
end
