# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_controller"
require "active_support/all"

# Load the app files
require_relative "../../../../app/controllers/nocheckout/stripe"
require_relative "../../../../app/controllers/nocheckout/stripe/checkout_session"

# Define ApplicationController for testing since it comes from the host app
class ApplicationController < ActionController::Base
end

require_relative "../../../../app/controllers/nocheckout/stripe/checkout_sessions_controller"

RSpec.describe NoCheckout::Stripe::CheckoutSessionsController do
  let(:controller) { described_class.new }
  let(:checkout_session_id) { "cs_test_123" }
  let(:checkout_session_url) { "https://checkout.stripe.com/pay/cs_test_123" }

  let(:mock_checkout_session) do
    double("Stripe::Checkout::Session",
      id: checkout_session_id,
      url: checkout_session_url,
      customer: "cus_123",
      subscription: "sub_123"
    )
  end

  before do
    # Mock Stripe module to avoid actual API calls
    stub_const("Stripe::Checkout::Session", Class.new do
      def self.create(**args)
        double("Stripe::Checkout::Session",
          id: "cs_test_123",
          url: "https://checkout.stripe.com/pay/cs_test_123"
        )
      end

      def self.retrieve(*args)
        double("Stripe::Checkout::Session",
          id: "cs_test_123",
          customer: "cus_123",
          subscription: "sub_123"
        )
      end
    end)

    # Mock controller methods
    allow(controller).to receive(:params).and_return(
      ActionController::Parameters.new(id: checkout_session_id, action: "show")
    )
    allow(controller).to receive(:redirect_to)
    allow(controller).to receive(:url_for).and_return("https://example.com/checkout_sessions/#{checkout_session_id}")
  end

  describe "inheritance" do
    it "inherits from ApplicationController" do
      expect(described_class.superclass).to eq(ApplicationController)
    end
  end

  describe "included modules" do
    it "includes CheckoutSession module" do
      expect(described_class.ancestors).to include(NoCheckout::Stripe::CheckoutSession)
    end
  end

  describe "module functionality" do
    it "has create_checkout_session method from module" do
      expect(described_class.protected_instance_methods).to include(:create_checkout_session)
    end

    it "has retrieve_checkout_session method from module" do
      expect(described_class.protected_instance_methods).to include(:retrieve_checkout_session)
    end

    it "has callback_url method from module" do
      expect(described_class.protected_instance_methods).to include(:callback_url)
    end

    it "has success_url method from module" do
      expect(described_class.protected_instance_methods).to include(:success_url)
    end

    it "has cancel_url method from module" do
      expect(described_class.protected_instance_methods).to include(:cancel_url)
    end

    it "has access to new action from module" do
      expect(controller).to respond_to(:new)
    end
  end

  describe "before_action callbacks" do
    it "sets up assign_created_checkout_session for new action" do
      callbacks = described_class._process_action_callbacks.select do |callback|
        callback.kind == :before && callback.filter.to_s.include?("assign_created_checkout_session")
      end
      expect(callbacks).not_to be_empty
    end

    it "sets up assign_retrieved_checkout_session for show action" do
      callbacks = described_class._process_action_callbacks.select do |callback|
        callback.kind == :before && callback.filter.to_s.include?("assign_retrieved_checkout_session")
      end
      expect(callbacks).not_to be_empty
    end
  end
end