# frozen_string_literal: true

require "rack"

module ApiSteward
  # Stage 2 Rack middleware: enforce a version's lifecycle before the app runs.
  #
  # If the gate turns the request away, we answer with an RFC 9457 problem document and
  # the app never sees it. Otherwise the request passes through untouched.
  #
  # An enforcement layer should not become a new way to take an app down, so if our own
  # logic raises, we fail open: the request proceeds.
  class Govern
    def initialize(app, config: ApiSteward.config, resolver: nil, gate: Gate.new)
      @app = app
      @config = config
      @resolver = resolver || Resolver.new(config)
      @gate = gate
    end

    def call(env)
      blocked_response(env) || @app.call(env)
    end

    private

    def blocked_response(env)
      resolution = @resolver.resolve(env)
      block = @gate.call(@config.version_info(resolution.version), resolution.client)
      Problem.response(block, instance: resolution.path) if block
    rescue StandardError
      nil # fail open: our own error must never break the app
    end
  end
end
