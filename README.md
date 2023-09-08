# NoCheckout

NoCheckout is a set of Rails controllers that does the least amount possible to integrate with Stripe. That might sound lazy at first, but when you read between the lines it means less stuff you have to maintain and less stuff that breaks.

How does it do the least amount possible? It sends your users down the [Stripe Checkout](https://stripe.com/docs/api/checkout/sessions) path for buying stuff, then sends them back to your site. There's also a StripeWebhooks controller that handles Stripe's callbacks.

That's it! You don't even have to include the `stripe.js` file on your website, which means your users get a faster more private browsing session.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add nocheckout

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install nocheckout

## Usage

This library comes with two controllers, both map closely to their respective Stripe docs.

### Webhooks Controller

[Stripe Webhooks](https://stripe.com/docs/webhooks) are extensive and keep your application up-to-date with what Stripe sees. In this example, we'll look at how to handle a subscriptioh that's expiring to update a User record in our database.

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

### Checkouts Controller

First you need to create a base Payments controller that includes credentials and how a customer is created.

```ruby
class PaymentsController < NoCheckout::Stripe::PaymentsController
  STRIPE_PUBLIC_KEY = ENV["STRIPE_PUBLIC_KEY"]
  STRIPE_PRIVATE_KEY = ENV["STRIPE_PRIVATE_KEY"]

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

Then, for each product you want to offer, create a controller and inherit the `PaymentsController`

```ruby
class PlusPlanPaymentsController < PaymentsController
    def create_checkout_session
      Stripe::Checkout::Session.create \
        customer: stripe_customer,
        mode: "subscription",
        payment_method_types: ["card"],
        line_items: [{
          price: strip_price,
          quantity: 1
        }],
        allow_promotion_codes: promotion_codes_enabled?,
        subscription_data: {
          trial_period_days: trail_days
        },
        metadata: { user_id: current_user.id },
        success_url: callback_url(state: :success),
        cancel_url: callback_url(state: :cancel)
    end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/nocheckout. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/nocheckout/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the NoCheckout project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/nocheckout/blob/main/CODE_OF_CONDUCT.md).
