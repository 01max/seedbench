module Providers
  # Describes the status and operator-facing details returned by a provider connection check.
  CheckResult = Data.define(:status, :code, :message)
end
