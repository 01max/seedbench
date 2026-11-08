class UploadsController < ApplicationController
  def create
    result = Releases::Intake.call(uploads: Array(params[:files]).compact_blank)
    flash[:upload_errors] = result.errors.map { |error| "#{error.filename} : #{error.message}" }
    redirect_to root_path, status: :see_other, notice: "#{result.releases.size} fichier(s) ajouté(s). Inspection en attente."
  rescue Releases::Intake::InvalidBatch => error
    redirect_to root_path, status: :see_other, alert: error.message
  end
end
