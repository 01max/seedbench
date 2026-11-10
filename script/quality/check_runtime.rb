require 'digest'
ARGV.replace([ 'verify' ])
require_relative 'runtime_workflows'
require_relative 'runtime_access'
require_relative 'runtime_workbench'
require_relative 'runtime_content'
require_relative 'runtime_ebooks'
require_relative 'runtime_preparation'
require_relative 'runtime_reviews'
require_relative 'runtime_ai'

record = RuntimeWorkflows.release
payload = record.payload_revisions.sole
path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)
abort 'Payload changed across recreation' unless Digest::SHA256.file(path).hexdigest == payload.sha256 && path.size == payload.size_bytes
abort 'Provider assignment state changed' unless record.provider_assignments.count == 4 && record.provider_assignments.pluck(:provider_connection_id).all?(&:nil?)
RuntimeWorkbench.verify(record)
RuntimeContent.verify(record)
RuntimeAccess.verify
RuntimeEbooks.verify
RuntimePreparation.verify
RuntimeReviews.verify
RuntimeAi.verify
puts 'Release revisions, human content, history, provider assignments, payload and workflow state survived recreation.'
