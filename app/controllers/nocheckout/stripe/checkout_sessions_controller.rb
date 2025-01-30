module NoCheckout::Stripe
  class CheckoutSessionsController < ApplicationController
    # Name of the URL parameter stripe uses for the Checkout Session ID.
    CHECKOUT_SESSION_ID_KEY = :checkout_session_id

    def new
      redirect_to checkout_session.url, allow_other_host: true
    end

    protected
      def checkout_session
        @checkout_session ||= retrieve_or_create_checkout_session
      end

      # Actually creates a Stripe checkout session. The reason I had to create
      # this method is so I could "curry" the values within so the `create_checkout_session`
      # could be a bit more readable and work better with inheritance.
      def create_checkout_session(**attributes)
        Stripe::Checkout::Session.create(**append_callback_urls(**attributes))
      end

      def append_callback_urls(success_url:, cancel_url:, **attributes)
        attributes.merge \
          success_url: concat_unescaped_stripe_checkout_session_id(success_url),
          cancel_url: concat_unescaped_stripe_checkout_session_id(cancel_url)
      end

      def retrieve_checkout_session(id: checkout_session_id)
        Stripe::Checkout::Session.retrieve id
      end

      def checkout_session_id
        params.fetch CHECKOUT_SESSION_ID_KEY, nil
      end

      def retrieve_or_create_checkout_session
        if checkout_session_id.present?
          retrieve_checkout_session
        else
          create_checkout_session
        end
      end

      def callback_url_for(*args, only_path: false, **kwargs)
        url_for(*args, only_path: only_path, **kwargs)
      end

      STRIPE_CALLBACK_PARAMETER = "#{CHECKOUT_SESSION_ID_KEY}={CHECKOUT_SESSION_ID}"

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

      # def success_url
      #   callback_url(state: :success)
      # end

      # def cancel_url
      #   callback_url(state: :cancel)
      # end

      # Retrives a customer from Stripe and returns a nil if the customer does not exist (instead)
      # of raising an exception, because this is not exceptional).
      def retrieve_customer(id:)
        return nil if id.blank?

        begin
          Stripe::Customer.retrieve(String(id))
        # Blurg ... wish Stripe just returned a response object that's not an exception.
        rescue Stripe::InvalidRequestError => e
          case e.response.data
            in error: { code: "resource_missing" }
              nil
            else
              raise
          end
        end
      end

      # Creates a customer and automatically converts the ID to a string so this
      # thing doesn't explode into oblivion.
      def create_customer(id: nil, **attributes)
        # If an ID is given, stripe insists that its a string.
        id = String(id) unless id.nil?
        Stripe::Customer.create(id: id, **attributes)
      end

      def retrieve_or_create_customer(id:, **attributes)
        retrieve_customer(id: id) || create_customer(id: id, **attributes)
      end
  end
end
