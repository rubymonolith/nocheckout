# frozen_string_literal: true

require_relative "nocheckout/version"
require "zeitwerk"

module NoCheckout
  Loader = Zeitwerk::Loader.for_gem.tap do |loader|
    loader.ignore "#{__dir__}/generators"
    loader.inflector.inflect "nocheckout" => "NoCheckout"
    loader.setup
  end

  class Error < StandardError; end
end
