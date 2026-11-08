module Settings
  class Overview
    def self.call
      ProviderConnection.order(:id).group_by(&:role)
    end
  end
end
