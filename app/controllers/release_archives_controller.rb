class ReleaseArchivesController < ApplicationController
  def create
    release = change_archive(archived: true)
    criteria = params.permit(:q, :state, :page).to_h.symbolize_keys
    criteria.except!(:state, :page) if criteria[:state] == 'archived'
    redirect_to root_path(**criteria), notice: t('workbench.archive.archived', title: release.title.presence || t('workbench.untitled')),
      status: :see_other
  end

  def destroy
    release = change_archive(archived: false)
    redirect_to release_path(release), notice: t('workbench.archive.restored', title: release.title.presence || t('workbench.untitled')),
      status: :see_other
  end

  private

  def change_archive(archived:)
    release = Release.find(params.expect(:release_id))
    release.with_lock do
      if release.archived_at.present? != archived
        release.update!(archived_at: archived ? Time.current : nil)
        Releases::RecordEvent.call(release_id: release.id, name: archived ? 'release.archived' : 'release.restored', actor: 'operator')
      end
    end
    release
  end
end
