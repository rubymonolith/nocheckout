## [Unreleased]

### Changed
- **BREAKING**: Refactored `CheckoutSessionsController` from a base class to a composable module
  - `NoCheckout::Stripe::CheckoutSession` is now a concern/module that you include in your controllers
  - Controllers no longer need to inherit from `NoCheckout::Stripe::CheckoutSessionsController`
  - Provides more flexibility - controllers can inherit from any base class in your app
  - All protected methods (`create_checkout_session`, `retrieve_checkout_session`, `callback_url`, etc.) remain the same
  - `@checkout_session` is still automatically assigned via before_action callbacks
  - See README for migration examples

### Added
- Comprehensive test suite for `CheckoutSession` module and `CheckoutSessionsController`
- Architecture documentation in README explaining the module-based design pattern

## [0.1.0] - 2023-09-08

- Initial release
