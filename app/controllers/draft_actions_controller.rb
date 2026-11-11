class DraftActionsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(draft: [ :kind, :expected_revision, :payload_choice, :confirmed, :choice, :snapshot_id, :write_id, :remote_id ])
    target = perform(attributes)
    target ? redirect_to(release_path(target), status: :see_other) : render_panel
  rescue Workflows::Start::UnresolvedEffect
    render_error(Drafts::Failure.new(:outcome_unknown), :unprocessable_content)
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Drafts::Failure, Providers::Failure, Releases::Save::InvalidChanges, Preparation::Failure => error
    render_error(error, :unprocessable_content)
  end

  private

  def perform(attributes)
    case attributes[:kind]
    when 'delete', 'recreate' then request_mutation(attributes)
    when 'reconcile' then reconcile(attributes)
    when 'link' then link_payload(attributes)
    when 'resolve' then resolve_conflict(attributes)
    when 'sync' then sync
    else raise Drafts::Failure.new(:invalid_action)
    end
  end

  def reconcile(attributes)
    Drafts::Reconcile.call(release_id: @release.id, write_id: attributes[:write_id], remote_id: attributes[:remote_id], confirmed: attributes[:confirmed] == '1')
    @draft_notice = t('drafts.reconciled')
    nil
  end

  def sync
    @draft_error = Drafts::Refresh.call(connection: @release.provider_assignments.find_by!(role: 'publishing').provider_connection)
    nil
  end

  def request_mutation(attributes)
    raise Drafts::Failure.new(:confirmation_required) unless attributes[:confirmed] == '1'
    arguments = { release_id: @release.id, expected_revision: Integer(attributes[:expected_revision], exception: false) }
    if attributes[:kind] == 'delete'
      Drafts::DeleteRequest.call(**arguments, remote_id: attributes[:remote_id], confirmed: attributes[:confirmed] == '1')
    else
      Drafts::Request.call(**arguments, recreate_confirmed: attributes[:confirmed] == '1')
    end
    @draft_notice = t('drafts.queued')
    nil
  end

  def resolve_conflict(attributes)
    Drafts::Resolve.call(release_id: @release.id, expected_revision: Integer(attributes[:expected_revision], exception: false),
      snapshot_id: attributes[:snapshot_id], choice: attributes[:choice])
    @draft_notice = t('drafts.resolved')
    nil
  end

  def link_payload(attributes)
    raise Drafts::Failure.new(:invalid_action) unless attributes[:kind] == 'link'
    target, revision = attributes[:payload_choice].to_s.split(':', 2)
    Drafts::Link.call(release_id: @release.id, payload_release_id: target, payload_revision: Integer(revision, exception: false),
      expected_revision: Integer(attributes[:expected_revision], exception: false), confirmed: attributes[:confirmed] == '1', choice: attributes[:choice])
  end

  def render_panel(status: :ok)
    @release.reload
    @draft_workspace = Drafts::Workspace.call(release: @release, payload_query: params.permit(:payload_query)[:payload_query].to_s)
    render partial: 'releases/draft_frame', status: status
  end

  def render_error(error, status)
    @draft_error = error.message
    render_panel(status: status)
  end
end
