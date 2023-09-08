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
        url_for(action: :show, path_only: false, **kwargs).concat("?checkout_session_id={CHECKOUT_SESSION_ID}")
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
