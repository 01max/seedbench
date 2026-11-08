require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
abort "Use the disposable quality container" unless
  ENV["RAILS_ENV"] == "test" && ENV["SEEDBENCH_QUALITY"] == "1"

require_relative "../config/environment"
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include SyntheticFiles
end
