# frozen_string_literal: true

require "rack"

module ApiSteward
  # Read-only Rack middleware for Stage 0.
  #
  # It lets the request through untouched, then records which version was used and who
  # made it. It must never break a request: our own bookkeeping is wrapped so a failure
  # here is swallowed. (Errors raised by the app itself propagate as usual.)
  #
  # When nobody is subscribed to the instrument, it does essentially nothing — no
  # resolution, no event — so an idle observe layer is close to free.
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
      return if @instrument.empty?

      resolution = @resolver.resolve(env)
      return unless resolution.version

      @instrument.publish(REQUEST_EVENT) do
        {
          version:   resolution.version,
          client_id: resolution.client.id,
          tier:      resolution.client.tier,
          status:    status,
          method:    resolution.request_method,
          path:      resolution.path,
          duration:  duration
        }
      end
    rescue StandardError
      # Bookkeeping must never break the request.
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
