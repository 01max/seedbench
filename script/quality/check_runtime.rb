require "digest"

connection = ApplicationRecord.connection
expected = connection.select_value("SELECT payload_hash FROM synthetic_markers")
payload = Rails.application.config.x.storage.fetch(:payload).join("synthetic-payload.bin")
abort "Payload or primary state changed across recreation" unless Digest::SHA256.file(payload).hexdigest == expected
job = SolidQueue::Job.find_by!(class_name: "SyntheticPersistenceJob")
abort "Queued work was not completed" unless job.finished_at
marker = Rails.application.config.x.storage.fetch(:scratch).join("queue-proof")
abort "Worker result missing" unless marker.read == "completed"
puts "Application state, payload bytes, and queued work survived container recreation."
