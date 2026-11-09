Rails.application.config.x.storage = {
  state: Pathname.new(ENV.fetch('SEEDBENCH_STATE_ROOT')),
  scratch: Pathname.new(ENV.fetch('SEEDBENCH_SCRATCH_ROOT')),
  payload: Pathname.new(ENV.fetch('SEEDBENCH_PAYLOAD_ROOT')),
  deluge_payload: ENV['DELUGE_PAYLOAD_ROOT']
}.freeze
