module NoCheckout::Stripe
  module CheckoutSession
    extend ActiveSupport::Concern

    # Unescaped placeholder for Stripe to insert the Checkout Session ID.
    STRIPE_CALLBACK_PARAMETER = "{CHECKOUT_SESSION_ID}".freeze

    # Escaped version that Rails will emit.
    ESCAPED_STRIPE_CALLBACK_PARAMETER = CGI.escape(STRIPE_CALLBACK_PARAMETER).freeze

    # Hoist the Stripe constant for easier access.
    Stripe = ::Stripe

    included do
      before_action def assign_created_checkout_session
        @checkout_session = create_checkout_session
      end, only: :new

      before_action def assign_retrieved_checkout_session
        @checkout_session = retrieve_checkout_session
      end, only: :show
    end

    # Creates a new Checkout Session and redirects to it.
    def new
      redirect_to @checkout_session.url, allow_other_host: true
    end

    protected

    # Creates a Stripe Checkout Session with callback URLs appended.
    def create_checkout_session(**)
      Stripe::Checkout::Session.create(success_url:, cancel_url:, **)
    end

    # Retrieves an existing Stripe Checkout Session by ID.
    def retrieve_checkout_session(*, **)
      Stripe::Checkout::Session.retrieve params.fetch(:id), *, **
    end

    def unescape_stripe_callback_parameter(url)
      url.gsub(ESCAPED_STRIPE_CALLBACK_PARAMETER, STRIPE_CALLBACK_PARAMETER)
    end

    # Default success URL. Override for custom behavior.
    def callback_url(**)
      unescape_stripe_callback_parameter url_for(
        action: :show,
        id: STRIPE_CALLBACK_PARAMETER,
        only_path: false,
        **
      )
    end
    alias :success_url :callback_url
    alias :cancel_url :callback_url
  end
end
