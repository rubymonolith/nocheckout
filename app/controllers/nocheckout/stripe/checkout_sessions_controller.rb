module NoCheckout::Stripe
  class CheckoutSessionsController < ApplicationController
    def new
      redirect_to checkout_session.url, allow_other_host: true
    end

    protected
      def checkout_session
        @checkout_session ||= find_or_create_checkout_session
      end

      def create_checkout_session
        raise "Implement a method here that returns a Stripe::Checkout::Session"
      end

      def customer_id
        current_user.id
      end

      # Actually creates a Stripe checkout session. The reason I had to create
      # this method is so I could "curry" the values within so the `create_checkout_session`
      # could be a bit more readable and work better with inheritance.
      def create_stripe_checkout_session(**attributes)
        Stripe::Checkout::Session.create \
          mode: "subscription",
          customer: stripe_customer,
          success_url: success_url,
          cancel_url: cancel_url,
          **attributes
      end

      def callback_url(**kwargs)
        # Yuck! I have to do the append at the end because rails params escape the `{CHECKOUT_SESSION_ID}` values
        # to `session_id=%7BCHECKOUT_SESSION_ID%7D`. This will work though, but its def not pretty and feels a tad
        # dangerous.
        concat_unescaped_stripe_checkout_session_id url_for(action: :show, only_path: false, **kwargs)
      end

      STRIPE_CALLBACK_PARAMETER = "checkout_session_id={CHECKOUT_SESSION_ID}"

      # For some reason Stripe decided to not escape the `{CHECKOUT_SESSION_ID}`, if we try to
      # pass it through Rails URL builders or the URI object, it will URL encode the value and
      # not work with stripe. Consequently, we have to do some weirdness here to append the callback.
      #
      # More information at https://stripe.com/docs/payments/checkout/custom-success-page#modify-success-url
      def concat_unescaped_stripe_checkout_session_id(url)
        if URI(url).query
          url.concat("&#{STRIPE_CALLBACK_PARAMETER}")
        else
          url.concat("?#{STRIPE_CALLBACK_PARAMETER}")
        end
      end

      def success_url
        callback_url(state: :success)
      end

      def cancel_url
        callback_url(state: :cancel)
      end

      def stripe_customer
        @stripe_customer ||= find_or_create_customer
      end

      def create_customer
        Stripe::Customer.create(
          id: String(customer_id),
          name: current_user.name,
          email: current_user.email
        )
      end

      def find_or_create_checkout_session
        if params.key? :checkout_session_id
          Stripe::Checkout::Session.retrieve params.fetch(:checkout_session_id)
        else
          create_checkout_session
        end
      end

      def find_or_create_customer
        return nil if customer_id.blank?

        begin
          Stripe::Customer.retrieve(String(customer_id))
        # Blurg ... wish Stripe just returned a response object that's not an exception.
        rescue Stripe::InvalidRequestError => e
          case e.response.data
            in error: { code: "resource_missing" }
              create_customer
            else
              raise
          end
        end
      end

  end
end
