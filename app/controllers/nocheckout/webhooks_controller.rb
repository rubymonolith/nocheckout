module NoCheckout
  class WebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token

    # Raised when a method is not implemented on the webhook
    # that's needed to handle the hook.
    UnhandledWebhookError = Class.new(RuntimeError)

    rescue_from UnhandledWebhookError, with: :unhandled_webhook

    def create
      dispatch_webhook
      head :no_content
    end

    private
      def dispatch_webhook
        logger.info "Webhook dispatching #{method_name.inspect}"
        if webhook_method_exists?
          public_send method_name
        else
          raise UnhandledWebhookError, "Webhook method #{method_name.inspect} does not exist"
        end
      end

      def method_name
        raise NotImplementedError
      end

      def webhook_methods
        public_methods(false)
      end

      def webhook_method_exists?
        webhook_methods.include? method_name.to_sym
      end

      def unhandled_webhook
        head :bad_request
      end
  end
end