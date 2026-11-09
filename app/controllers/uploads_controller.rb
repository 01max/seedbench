class UploadsController < ApplicationController
  def create
    result = Releases::Intake.call(uploads: Array(params[:files]).compact_blank)
    finish_upload(result)
  rescue Releases::Intake::InvalidBatch => error
    redirect_to root_path, status: :see_other, alert: error.message
  end

  private

  def finish_upload(result)
    releases, errors = result.releases, result.errors
    release = releases.first
    flash[:upload_errors] = errors.map { |error| t('workbench.uploads.rejection', filename: error.filename, message: error.message) } if errors.any?
    flash[:notice] = t('workbench.uploads.accepted', count: releases.size) if release
    redirect_to release ? release_path(release) : root_path, status: :see_other
  end
end
