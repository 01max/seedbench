module Content
  class Capture
    def self.call(release:, kind:)
      inputs = Inputs.new(release)
      Dependencies.call(inputs: inputs, values: Values.new(inputs).call, kind: kind)
    end
  end
end
