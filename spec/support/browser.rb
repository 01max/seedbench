require 'capybara/rspec'
require 'selenium-webdriver'

Capybara.register_driver :headless_chromium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = '/usr/bin/chromium'
  # Synthetic, network-isolated test container; no privileged browser sandbox mount.
  options.add_argument('--no-sandbox')
  options.add_argument('--headless=new')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1000')
  service = Selenium::WebDriver::Chrome::Service.new(path: '/usr/bin/chromedriver')
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end
Capybara.server = :puma, { Silent: true }
Capybara.save_path = '/tmp/browser-artifacts'
Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :headless_chromium }
  # A reused Chromium session can reject about:blank even from a static page.
  config.after(:each, type: :system) { Capybara.current_session.driver.quit }
end
