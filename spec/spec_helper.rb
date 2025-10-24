# frozen_string_literal: true

require "nocheckout"
require "stripe"

# Configure Stripe for testing (won't make real requests)
Stripe.api_key = "sk_test_fake_key_for_testing"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end