# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_controller"
require "active_support/all"

# Load the app files
require_relative "../../../../app/controllers/nocheckout/stripe"
require_relative "../../../../app/controllers/nocheckout/stripe/checkout_session"

RSpec.describe NoCheckout::Stripe::CheckoutSession do
  # Create a test controller that includes the module
  let(:controller_class) do
    Class.new(ActionController::Base) do
      include NoCheckout::Stripe::CheckoutSession

      attr_accessor :params_hash, :redirected_to, :redirect_options

      def params
        @params ||= ActionController::Parameters.new(params_hash || {})
      end

      def url_for(options = {})
        "https://example.com/checkout_sessions/#{options[:id]}?action=#{options[:action]}"
      end

      def redirect_to(url, options = {})
        @redirected_to = url
        @redirect_options = options
      end
    end
  end

  let(:controller) { controller_class.new }
  let(:checkout_session_id) { "cs_test_a1b2c3d4e5f6" }

  describe "constants" do
    it "defines STRIPE_CALLBACK_PARAMETER as unescaped placeholder" do
      expect(described_class::STRIPE_CALLBACK_PARAMETER).to eq("{CHECKOUT_SESSION_ID}")
    end

    it "defines ESCAPED_STRIPE_CALLBACK_PARAMETER as CGI escaped version" do
      expect(described_class::ESCAPED_STRIPE_CALLBACK_PARAMETER).to eq("%7BCHECKOUT_SESSION_ID%7D")
    end

    it "hoists Stripe constant for easier access" do
      expect(described_class::Stripe).to eq(::Stripe)
    end
  end

  describe "included" do
    it "can be included in a controller" do
      expect(controller_class.ancestors).to include(described_class)
    end

    it "sets up before_action callbacks" do
      callbacks = controller_class._process_action_callbacks.select { |cb| cb.kind == :before }
      expect(callbacks.size).to be >= 2
    end
  end

  describe "#new" do
    let(:checkout_session) do
      Stripe::Checkout::Session.construct_from({
        id: checkout_session_id,
        object: "checkout.session",
        url: "https://checkout.stripe.com/c/pay/#{checkout_session_id}",
        livemode: false,
        status: "open"
      })
    end

    before do
      controller.params_hash = {action: "new"}
      allow(controller).to receive(:create_checkout_session).and_return(checkout_session)
    end

    it "assigns @checkout_session from create_checkout_session" do
      controller.send(:assign_created_checkout_session)
      expect(controller.instance_variable_get(:@checkout_session)).to eq(checkout_session)
    end

    it "redirects to the checkout session URL" do
      controller.send(:assign_created_checkout_session)
      controller.new
      expect(controller.redirected_to).to eq(checkout_session.url)
    end

    it "allows redirecting to other hosts" do
      controller.send(:assign_created_checkout_session)
      controller.new
      expect(controller.redirect_options[:allow_other_host]).to be true
    end
  end

  describe "#show" do
    let(:checkout_session) do
      Stripe::Checkout::Session.construct_from({
        id: checkout_session_id,
        object: "checkout.session",
        customer: "cus_test123",
        subscription: "sub_test456",
        status: "complete",
        payment_status: "paid"
      })
    end

    before do
      controller.params_hash = {id: checkout_session_id, action: "show"}
      allow(controller).to receive(:retrieve_checkout_session).and_return(checkout_session)
    end

    it "assigns @checkout_session from retrieve_checkout_session" do
      controller.send(:assign_retrieved_checkout_session)
      expect(controller.instance_variable_get(:@checkout_session)).to eq(checkout_session)
    end
  end

  describe "#create_checkout_session" do
    let(:success_url) { "https://example.com/success" }
    let(:cancel_url) { "https://example.com/cancel" }
    let(:checkout_session) do
      Stripe::Checkout::Session.construct_from({
        id: "cs_test_new123",
        object: "checkout.session",
        url: "https://checkout.stripe.com/c/pay/cs_test_new123",
        success_url: success_url,
        cancel_url: cancel_url,
        livemode: false
      })
    end

    before do
      allow(controller).to receive(:success_url).and_return(success_url)
      allow(controller).to receive(:cancel_url).and_return(cancel_url)
    end

    it "calls Stripe::Checkout::Session.create with success and cancel URLs" do
      expect(Stripe::Checkout::Session).to receive(:create).with(
        success_url: success_url,
        cancel_url: cancel_url
      ).and_return(checkout_session)

      result = controller.send(:create_checkout_session)
      expect(result).to be_a(Stripe::Checkout::Session)
      expect(result.success_url).to eq(success_url)
      expect(result.cancel_url).to eq(cancel_url)
    end

    context "when additional parameters are provided" do
      let(:checkout_session_with_params) do
        Stripe::Checkout::Session.construct_from({
          id: "cs_test_subscription",
          object: "checkout.session",
          url: "https://checkout.stripe.com/c/pay/cs_test_subscription",
          mode: "subscription",
          line_items: {
            object: "list",
            data: [{
              price: "price_123",
              quantity: 1
            }]
          }
        })
      end

      it "passes them through to Stripe" do
        expect(Stripe::Checkout::Session).to receive(:create).with(
          success_url: success_url,
          cancel_url: cancel_url,
          mode: "subscription",
          line_items: [{price: "price_123", quantity: 1}]
        ).and_return(checkout_session_with_params)

        result = controller.send(:create_checkout_session,
          mode: "subscription",
          line_items: [{price: "price_123", quantity: 1}]
        )
        expect(result).to be_a(Stripe::Checkout::Session)
        expect(result.mode).to eq("subscription")
      end
    end
  end

  describe "#retrieve_checkout_session" do
    let(:checkout_session) do
      Stripe::Checkout::Session.construct_from({
        id: checkout_session_id,
        object: "checkout.session",
        customer: "cus_test123",
        subscription: "sub_test456"
      })
    end

    before do
      controller.params_hash = {id: checkout_session_id}
    end

    it "calls Stripe::Checkout::Session.retrieve with the session ID from params" do
      expect(Stripe::Checkout::Session).to receive(:retrieve)
        .with(checkout_session_id)
        .and_return(checkout_session)

      result = controller.send(:retrieve_checkout_session)
      expect(result).to be_a(Stripe::Checkout::Session)
      expect(result.id).to eq(checkout_session_id)
      expect(result.customer).to eq("cus_test123")
    end

    context "when additional parameters are provided" do
      let(:expanded_checkout_session) do
        Stripe::Checkout::Session.construct_from({
          id: checkout_session_id,
          object: "checkout.session",
          customer: {
            id: "cus_test123",
            object: "customer",
            email: "customer@example.com"
          },
          subscription: {
            id: "sub_test456",
            object: "subscription",
            status: "active"
          }
        })
      end

      it "passes them through to Stripe" do
        expect(Stripe::Checkout::Session).to receive(:retrieve)
          .with(checkout_session_id, {expand: ["customer", "subscription"]})
          .and_return(expanded_checkout_session)

        result = controller.send(:retrieve_checkout_session, expand: ["customer", "subscription"])
        expect(result).to be_a(Stripe::Checkout::Session)
        expect(result.customer).to be_a(Stripe::Customer)
        expect(result.customer.email).to eq("customer@example.com")
      end
    end
  end

  describe "#unescape_stripe_callback_parameter" do
    subject { controller.send(:unescape_stripe_callback_parameter, url) }

    context "with escaped placeholder in URL" do
      let(:url) { "https://example.com/callback?session_id=%7BCHECKOUT_SESSION_ID%7D" }

      it "replaces escaped placeholder with unescaped version" do
        expect(subject).to eq("https://example.com/callback?session_id={CHECKOUT_SESSION_ID}")
      end
    end

    context "with other query parameters" do
      let(:url) { "https://example.com/callback?foo=bar&session_id=%7BCHECKOUT_SESSION_ID%7D&baz=qux" }

      it "preserves other query parameters" do
        expect(subject).to include("foo=bar")
        expect(subject).to include("baz=qux")
        expect(subject).to include("{CHECKOUT_SESSION_ID}")
      end
    end
  end

  describe "#callback_url" do
    subject { controller.send(:callback_url) }

    it { is_expected.to include("{CHECKOUT_SESSION_ID}") }
    it { is_expected.not_to include("%7BCHECKOUT_SESSION_ID%7D") }

    it "uses the show action" do
      expect(controller).to receive(:url_for) do |options|
        expect(options[:action]).to eq(:show)
        "https://example.com/show?id={CHECKOUT_SESSION_ID}"
      end
      controller.send(:callback_url)
    end

    it "generates an absolute URL" do
      expect(controller).to receive(:url_for) do |options|
        expect(options[:only_path]).to eq(false)
        "https://example.com/show?id={CHECKOUT_SESSION_ID}"
      end
      controller.send(:callback_url)
    end

    context "with additional options" do
      it "passes them through to url_for" do
        expect(controller).to receive(:url_for) do |options|
          expect(options[:protocol]).to eq("https")
          expect(options[:host]).to eq("custom.example.com")
          "https://custom.example.com/show?id={CHECKOUT_SESSION_ID}"
        end
        controller.send(:callback_url, protocol: "https", host: "custom.example.com")
      end
    end
  end

  describe "#success_url" do
    it "is aliased to callback_url" do
      expect(controller.method(:success_url)).to eq(controller.method(:callback_url))
    end
  end

  describe "#cancel_url" do
    it "is aliased to callback_url" do
      expect(controller.method(:cancel_url)).to eq(controller.method(:callback_url))
    end
  end
end