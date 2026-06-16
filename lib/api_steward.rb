# frozen_string_literal: true

require "api_steward/version"
require "api_steward/keys"
require "api_steward/api_version"
require "api_steward/configuration"
require "api_steward/client"
require "api_steward/instrument"
require "api_steward/strategies"
require "api_steward/identity"
require "api_steward/resolver"
require "api_steward/usage"
require "api_steward/problem"
require "api_steward/gate"
require "api_steward/observe"
require "api_steward/signal"
require "api_steward/govern"
require "api_steward/dashboard"
require "api_steward/dashboard/view"

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
    #     c.version "v1", status: :deprecated, sunset: "2026-11-11"
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

    # A live, in-memory tally of observed requests, subscribed to the instrument.
    # The dashboard reads from this. Touch it at boot so it starts counting early.
    def usage
      @usage ||= Usage.new.subscribe_to(instrument)
    end

    # Canonical form of a version token, so "V1" and "v1" line up everywhere — in the
    # registry, in lookups, and in telemetry. Returns nil for a blank token.
    def normalize_version(token)
      token = token.to_s
      token.empty? ? nil : token.downcase
    end

    # Reset global state. Mainly useful in tests.
    def reset!
      @config = nil
      @instrument = nil
      @usage = nil
    end
  end
end
