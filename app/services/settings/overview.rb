module Settings
  # Collects provider connections and defaults for the operator's settings screen.
  class Overview
    def self.call
      ProviderConnection.order(:id).group_by(&:role)
    end
  end
end
