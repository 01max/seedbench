require 'rails_helper'
require 'net/http'

RSpec.describe WebMock do
  it 'blocks an unexpected external request before it reaches the network' do
    expect { Net::HTTP.get(URI('https://unexpected.invalid/fixture')) }
      .to raise_error(described_class::NetConnectNotAllowedError)
  end
end
