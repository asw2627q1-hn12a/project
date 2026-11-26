require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Ubuntu can block the sandbox in Chrome downloaded by Selenium.
    options.add_argument("--no-sandbox") if ENV["GITHUB_ACTIONS"] == "true"
  end
end
