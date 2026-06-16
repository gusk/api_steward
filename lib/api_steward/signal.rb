# frozen_string_literal: true

require "rack"
require "time"

module ApiSteward
  # Stage 1 Rack middleware: add deprecation signals to responses.
  #
  # For a version that has a deprecation or sunset date, it sets the standard
  # Deprecation (RFC 9745) and Sunset (RFC 8594) response headers, plus an optional
  # Link header pointing at more detail. It never blocks a request, and never breaks
  # one: any failure here is swallowed and the response goes out unchanged.
  class Signal
    def initialize(app, config: ApiSteward.config, resolver: nil)
      @app = app
      @config = config
      @resolver = resolver || Resolver.new(config)
    end

    def call(env)
      status, headers, body = @app.call(env)
      annotate(env, headers)
      [status, headers, body]
    end

    private

    def annotate(env, headers)
      version = @resolver.call(Rack::Request.new(env)).version
      return unless version

      info = @config.version_info(version)
      return unless info

      headers["deprecation"] = "@#{info.deprecation_on.to_i}" if info.signals_deprecation?
      headers["sunset"] = info.sunset_on.httpdate if info.signals_sunset?
      add_link(headers, info.link) if info.link
    rescue StandardError
      # Signaling must never break the request.
    end

    def add_link(headers, url)
      link = %(<#{url}>; rel="deprecation")
      existing = headers["link"]
      headers["link"] = existing ? "#{existing}, #{link}" : link
    end
  end
end
