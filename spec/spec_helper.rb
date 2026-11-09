ENV['DISABLE_BOOTSNAP'] = '1'
require 'simplecov'

SimpleCov.start do
  coverage_dir ENV.fetch('COVERAGE_DIR', '/tmp/coverage')
  track_files '{app,lib}/**/*.rb'
  add_filter do |source|
    !source.filename.start_with?("#{SimpleCov.root}/app/", "#{SimpleCov.root}/lib/")
  end
  add_group 'Services', 'app/services'
  minimum_coverage line: 90
end

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.order = :random
  Kernel.srand config.seed
end
