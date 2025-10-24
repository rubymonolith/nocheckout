module NoCheckout::Stripe
  class CheckoutSessionsController < ApplicationController
    include CheckoutSession
  end
end
