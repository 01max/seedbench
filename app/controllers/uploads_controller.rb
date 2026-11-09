class UploadsController < ApplicationController
  def create
    result = Releases::Intake.call(uploads: Array(params[:files]).compact_blank)
    finish_upload(result)
  rescue Releases::Intake::InvalidBatch => error
    redirect_to root_path, status: :see_other, alert: error.message
  end

  private

  def finish_upload(result)
    flash[:upload_errors] = result.errors.map { |error| t("workbench.uploads.rejection", filename: error.filename, message: error.message) }
    location = result.releases.any? ? release_path(result.releases.first) : root_path
    redirect_to location, status: :see_other, notice: t("workbench.uploads.accepted", count: result.releases.size)
  end
end
