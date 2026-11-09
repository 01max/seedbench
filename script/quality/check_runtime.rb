require "digest"
ARGV.replace([ "verify" ])
require_relative "runtime_workflows"
require_relative "runtime_access"
require_relative "runtime_workbench"

record = RuntimeWorkflows.release
payload = record.payload_revisions.sole
path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)
abort "Payload changed across recreation" unless Digest::SHA256.file(path).hexdigest == payload.sha256 && path.size == payload.size_bytes
abort "Provider assignment state changed" unless record.provider_assignments.count == 4 && record.provider_assignments.pluck(:provider_connection_id).all?(&:nil?)
RuntimeWorkbench.verify(record)
RuntimeAccess.verify
puts "Release revisions, human content, history, provider assignments, payload and workflow state survived recreation."
