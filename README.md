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

To implement the checkout:

```
class PaymentsController < NoCheckout::PaymentsController
  STRIPE_PUBLIC_KEY = "pk_..."
  STRIPE_PRIVATE_KEY = "sk_..."
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
