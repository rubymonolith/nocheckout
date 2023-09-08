module NoCheckout
  class Stripe::WebhooksController < WebhooksController
    STRIPE_SIGNING_SECRET = ENV["STRIPE_SIGNING_SECRET"]

    rescue_from JSON::ParserError, with: :invalid_payload
    rescue_from Stripe::SignatureVerificationError, with: :signature_verification_failure

    def customer_subscription_created
    end

    def customer_subscription_updated
    end

    def customer_subscription_deleted
    end

    def customer_subscription_trial_will_end
    end

    def customer_source_created
    end

    def customer_updated
    end

    def invoice_finalized
    end

    def invoice_created
    end

    def invoice_paid
    end

    def invoiceitem_created
    end

    def invoiceitem_updated
    end

    def payment_intent_created
    end

    def payment_intent_succeeded
    end

    def invoice_payment_succeeded
    end

    private
      def event
        @event ||= Stripe::Webhook.construct_event(request.body.read, stripe_signature, stripe_signing_secret)
      end

      def data
        event.data.object
      end

      def method_name
        event.type.gsub(".", "_")
      end

      def stripe_signature
        request.env.fetch("HTTP_STRIPE_SIGNATURE")
      end

      def stripe_signing_secret
        self.class::STRIPE_SIGNING_SECRET
      end

      def invalid_payload
        logger.error "Could not parse webhook payload."
        head :bad_request
      end

      def signature_verification_failure
        logger.error "Webhook signature verification failed."
        head :bad_request
      end
  end
end