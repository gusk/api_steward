# frozen_string_literal: true

require "api_steward/version"
require "api_steward/api_version"
require "api_steward/configuration"
require "api_steward/client"
require "api_steward/instrument"
require "api_steward/resolver"
require "api_steward/observe"
require "api_steward/signal"
require "api_steward/dashboard"

# api_steward — see, signal, and govern the lifecycle of your API versions.
#
# The library is plain Rack and depends only on `rack`. The global helpers below are a
# convenience; for tests or multiple instances you can build a Configuration yourself
# and pass it to the middleware explicitly.
module ApiSteward
  class Error < StandardError; end

  class << self
    # Configure the global instance.
    #
    #   ApiSteward.configure do |c|
    #     c.version_from :path
    #   end
    def configure
      yield config if block_given?
      config
    end

    def config
      @config ||= Configuration.new
    end

    def instrument
      @instrument ||= Instrument.new
    end

    # Reset global state. Mainly useful in tests.
    def reset!
      @config = nil
      @instrument = nil
    end
  end
end
