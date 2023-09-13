# NoCheckout

[![Gem Version](https://badge.fury.io/rb/nocheckout.svg)](https://badge.fury.io/rb/nocheckout) [![Tests](https://github.com/rubymonolith/nocheckout/actions/workflows/main.yml/badge.svg)](https://github.com/rubymonolith/nocheckout/actions/workflows/main.yml)

> [!IMPORTANT]
> This project is a work in progress. This README was written to better understand the implementation for developers. **Some of the APIs may not have yet been implemented, renamed, or removed**. When the API settles down and is running in production for a while, a 1.0 release will be cut and this notice removed.

NoCheckout is a set of Rails controllers that does the least amount possible to integrate with Stripe. That might sound lazy at first, and it is, but if you try to roll your own signup and payment form and keep your Rails database sync'ed with your payment info, you'll quickly find out there's better things in life to worry about. Its best to delegate as much payment collection, processing, and reporting to your payment processor as you can. Fortunately Stripe does a great job sweating all the details in checkout UX and reporting that I'm OK delegating everything out to them.

This gem does that--it sends your users down the [Stripe Checkout](https://stripe.com/docs/payments/checkout/how-checkout-works) path for buying stuff, then sends them back to your site via the CheckoutSessions controller. There's also a StripeWebhooks controller that handles Stripe's callbacks in a plain 'ol controller. You don't even have to include the `stripe.js` file on your website, which means your users experience a faster, more private browsing session.

That's it! There's not much to it and that's the point.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add nocheckout

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install nocheckout

## Get a Stripe API key

Before you do anything you'll need to go to https://dashboard.stripe.com/test/apikeys and get the "Secret Key". You can set the `STRIPE_SECRET_KEY` environment variable or create an initializer using your configuration manager of choice:

```ruby
# Set the API key in ./config/initializers/stripe.rb
Stripe.api_key = Rails.configuration.stripe[:secret_key]
```

## Usage

This library comes with two controllers, both map closely to their respective Stripe docs.

### Checkout Sessions Controller

[Stripe Checkout Sessions](https://stripe.com/docs/api/checkout/sessions) send users from your website to a branded stripe.com page where they can enter their credit card details and complete the purchase. Once the purchase is complete, the user is redirected back to your website.

The NoCheckout::CheckoutSessionsController handles the interface between Stripe and your Rails application and tries to be as small as possible.

To get started, create a base CheckoutSessionsController that maps the Users from your application with [Stripe Customers](https://stripe.com/docs/api/customers).

```ruby
class CheckoutSessionsController < NoCheckout::Stripe::CheckoutSessionsController
  protected
    def customer_id
      user.id
    end

    def create_customer
      Stripe::Customer.create(
        id: customer_id,
        name: user.name,
        email: user.email
      )
    end
end
```

Then, for each product you want to offer, create a controller and inherit the `CheckoutSessionsController`.

```ruby
class PlusCheckoutSessionsController < PaymentsController
  STRIPE_PRICE = "price_..."

  protected
    def create_checkout_session
      create_stripe_checkout_session line_items: [{
        price: STRIPE_PRICE,
        quantity: 1
      }]
    end
end
```

There's a lot of different ways you can wire up the controllers depending on how many Stripe prices are in your application. This README assumes you're selling just a few products, so the prices are hard coded as constants in the controller. This could easily be populated from a database.

### Webhooks Controller

[Stripe Webhooks](https://stripe.com/docs/webhooks) are extensive and keep your application up-to-date with what Stripe. In this example, we'll look at how to handle a subscription that's expiring and update a User record in our database.

```ruby
class StripesController < NoCheckout::Stripe::WebhooksController
  STRIPE_SIGNING_SECRET = ENV["STRIPE_SIGNING_SECRET"]

  protected

  def customer_subscription_created
    user.subscription_expires_at data.current_period_end
  end

  def customer_subscription_updated
    user.subscription_expires_at data.current_period_end
  end

  def customer_subscription_deleted
    user.subscription_expires_at Time.now
  end

  def user
    @user ||= User.find data.customer
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubymonolith/nocheckout. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/rubymonolith/nocheckout/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the NoCheckout project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rubymonolith/nocheckout/blob/main/CODE_OF_CONDUCT.md).
