require_relative "../../config/environment"

# This synthetic job is loaded only by the disposable runtime verification stack.
class SyntheticPersistenceJob < ApplicationJob
  def perform
    File.write(Rails.application.config.x.storage.fetch(:scratch).join("queue-proof"), "completed")
  end
end
