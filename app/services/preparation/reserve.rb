module Preparation
  class Reserve
    def self.call(operation:, payload:, destination:, paths: Paths.new)
      existing = PayloadMove.find_by(workflow_operation_id: operation.id)
      return existing if existing

      preflight = Preflight.call(payload: payload, destination: destination, paths: paths)
      PayloadMove.create!(release: operation.release, payload_revision: payload, workflow_operation: operation,
        source_locator: payload.locator, destination_locator: destination,
        source_device: preflight.identity.dev, source_inode: preflight.identity.ino,
        root_device: preflight.root_identity.dev, root_inode: preflight.root_identity.ino)
    rescue ActiveRecord::RecordNotUnique
      raise Failure.new(:collision)
    end
  end
end
