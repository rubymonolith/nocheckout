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

## Checkout Sessions Controller

[Stripe Checkout Sessions](https://stripe.com/docs/api/checkout/sessions) send users from your website to a branded stripe.com page where they can enter their credit card details and complete the purchase. Once the purchase is complete, the user is redirected back to your website.

NoCheckout provides a `CheckoutSession` module that you can include in your controllers to handle the interface between Stripe and your Rails application. The module is designed to be minimal and flexible.

To get started, create a controller and include the `NoCheckout::Stripe::CheckoutSession` module. The module provides:

- **`#new` action**: Creates a Checkout Session and redirects users to Stripe
- **`#show` action**: Handles the callback when users return from Stripe
- **Protected methods**: `create_checkout_session`, `retrieve_checkout_session`, `callback_url`, `success_url`, `cancel_url`

The module automatically sets up `before_action` callbacks that:
- Call `create_checkout_session` and assign it to `@checkout_session` before the `new` action
- Call `retrieve_checkout_session` and assign it to `@checkout_session` before the `show` action

### Create user record after checkout is complete

This approach creates a new user record after the checkout is complete with the name and email they give during the Stripe checkout process.

```ruby
class PaymentsController < ApplicationController
  include NoCheckout::Stripe::CheckoutSession

  STRIPE_PRICE = "price_..."

  def show
    # @checkout_session is automatically assigned by the module
    customer = Stripe::Customer.retrieve @checkout_session.customer
    subscription = Stripe::Subscription.retrieve @checkout_session.subscription

    # Do stuff with Stripe info
    user = User.find_or_create_by email: customer.email
    customer.metadata.user_id = user.id
    customer.save
    user.name = customer.name
    user.save!

    # In this example we set the current user to stripe info. This likely
    # doesn't make sense for your security context, so be careful...
    self.current_user = user
    redirect_to root_url
  end

  protected
    def create_checkout_session
      super \
        mode: "subscription",
        line_items: [{
          price: self.class::STRIPE_PRICE,
          quantity: 1
        }]
    end
end
```

Then, for each product you want to offer, create a controller and include the `CheckoutSession` module. You can also inherit from a base controller:

```ruby
class PlusCheckoutSessionsController < PaymentsController
  STRIPE_PRICE = "price_..."
end
```

Or include the module directly:

```ruby
class ProCheckoutSessionsController < ApplicationController
  include NoCheckout::Stripe::CheckoutSession
  
  STRIPE_PRICE = "price_..."

  def show
    # Handle callback after successful checkout
    redirect_to dashboard_url, notice: "Welcome to Pro!"
  end

  protected
    def create_checkout_session
      super \
        mode: "subscription",
        line_items: [{price: self.class::STRIPE_PRICE, quantity: 1}]
    end
end
```

There's a lot of different ways you can wire up the controllers depending on how many Stripe prices are in your application. This README assumes you're selling just a few products, so the prices are hard coded as constants in the controller. This could easily be populated from a database.

### Create a user record before checkout is complete

```ruby
class PaymentsController < ApplicationController
  include NoCheckout::Stripe::CheckoutSession
  
  before_action :authenticate_user! # Loads a current_user

  STRIPE_PRICE = "price_..."

  def show
    # @checkout_session is automatically assigned by the module
    customer = Stripe::Customer.retrieve @checkout_session.customer
    subscription = Stripe::Subscription.retrieve @checkout_session.subscription

    # Update user with subscription info
    current_user.update!(
      stripe_customer_id: customer.id,
      stripe_subscription_id: subscription.id
    )

    redirect_to root_url, notice: "Subscription activated!"
  end

  protected
    def create_checkout_session
      # Find or create a Stripe customer for the current user
      customer = if current_user.stripe_customer_id.present?
        Stripe::Customer.retrieve(current_user.stripe_customer_id)
      else
        Stripe::Customer.create(
          email: current_user.email,
          name: current_user.name,
          metadata: {user_id: current_user.id}
        )
      end

      super \
        mode: "subscription",
        customer: customer.id,
        line_items: [{
          price: self.class::STRIPE_PRICE,
          quantity: 1
        }]
    end
end
```

### Customizing callback URLs

By default, the module uses the same URL for both `success_url` and `cancel_url`, pointing to the `show` action with the Checkout Session ID. You can override these methods to customize the behavior:

```ruby
class PaymentsController < ApplicationController
  include NoCheckout::Stripe::CheckoutSession

  protected
    def success_url
      # Custom success URL
      callback_url(status: "success")
    end

    def cancel_url
      # Custom cancel URL - could point to a different action or controller
      pricing_url
    end
end
```

### Routes

Don't forget to add routes for your checkout controllers:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :payments, controller: "payments", only: [:new, :show]
  
  # Or for multiple products:
  resource :plus_checkout, controller: "plus_checkout_sessions", only: [:new, :show]
  resource :pro_checkout, controller: "pro_checkout_sessions", only: [:new, :show]
end
```

## Architecture

The `CheckoutSession` module is designed as a Rails concern that provides a minimal, composable interface for Stripe Checkout Sessions. Here's how it works:

### Module-Based Design

Instead of inheriting from a base controller class, you **include** the `CheckoutSession` module into your own controllers. This gives you maximum flexibility:

- **No forced inheritance**: Your controllers can inherit from any base controller in your app
- **Composable**: Mix and match with other concerns and modules
- **Customizable**: Override any method to change behavior
- **Testable**: Each piece can be tested independently

### What the Module Provides

1. **Before Actions**: Automatically sets up `@checkout_session` for `new` and `show` actions
2. **Action Methods**: Provides `#new` action that redirects to Stripe
3. **Protected Methods**: Gives you `create_checkout_session`, `retrieve_checkout_session`, `callback_url`, `success_url`, and `cancel_url` to override as needed
4. **Constants**: Includes helper constants for handling Stripe's callback parameter

### Customization Pattern

The module follows a simple pattern:

```ruby
class YourController < ApplicationController
  include NoCheckout::Stripe::CheckoutSession
  
  # 1. Override protected methods to customize Stripe session creation
  protected
    def create_checkout_session
      super(mode: "payment", line_items: [...])
    end
  
  # 2. Implement show action to handle the callback
  def show
    # Access @checkout_session that was automatically retrieved
    # Do your business logic
    # Redirect user
  end
end
```

## Webhooks Controller

[Stripe Webhooks](https://stripe.com/docs/webhooks) are extensive and keep your application up-to-date with what Stripe. In this example, we'll look at how to handle a subscription that's expiring and update a User record in our database.

```ruby
class StripesController < NoCheckout::Stripe::WebhooksController
  STRIPE_SIGNING_SECRET = ENV["STRIPE_SIGNING_SECRET"]

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
