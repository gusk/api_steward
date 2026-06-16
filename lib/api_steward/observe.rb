# frozen_string_literal: true

require "rack"

module ApiSteward
  # Read-only Rack middleware for Stage 0.
  #
  # It lets the request through untouched, then records which version was used and who
  # made it. It must never break a request: our own bookkeeping is wrapped so that a
  # failure here is swallowed. (Errors raised by the app itself are left alone to
  # propagate as usual.)
  class Observe
    def initialize(app, config: ApiSteward.config, instrument: ApiSteward.instrument, resolver: nil)
      @app = app
      @instrument = instrument
      @resolver = resolver || Resolver.new(config)
    end

    def call(env)
      started = monotonic
      status, headers, body = @app.call(env)
      record(env, status, monotonic - started)
      [status, headers, body]
    end

    private

    def record(env, status, duration)
      request = Rack::Request.new(env)
      resolution = @resolver.call(request)
      return unless resolution.version

      @instrument.publish("api_steward.request", {
        version:   resolution.version,
        client_id: resolution.client.id,
        tier:      resolution.client.tier,
        status:    status,
        method:    request.request_method,
        path:      resolution.path,
        duration:  duration
      })
    rescue StandardError
      # Bookkeeping must never break the request.
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
