require "stripe"

module NoCheckout::Stripe
  # Include the root Stripe namespace so developers can work
  # within these controllers without needing to ::Stripe::Customer.create
  # all over the place.
  include ::Stripe
end