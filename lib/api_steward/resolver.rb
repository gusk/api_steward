# frozen_string_literal: true

require "rack"

module ApiSteward
  # What we learned about a request: which version it targets and who made it.
  Resolution = Data.define(:version, :client, :path, :request_method)

  # Turns a Rack request into a Resolution.
  #
  # Version detection follows the configuration. Client identification is best-effort
  # at this stage: if the app set env["api_steward.client"], we use it; otherwise the
  # caller is treated as anonymous. (Trusted identity for enforcement comes later.)
  class Resolver
    # A version segment (v1, v2, ...) bounded by a slash or the ends of the path.
    # Matching directly avoids splitting the whole path into an array each request.
    PATH_VERSION = %r{(?:\A|/)(v\d+)(?:/|\z)}i

    def initialize(config)
      @config = config
    end

    # Resolve once per request and reuse the result across middlewares, by caching it
    # in the Rack env.
    def resolve(env)
      env[RESOLUTION_ENV_KEY] ||= call(Rack::Request.new(env))
    end

    def call(request)
      Resolution.new(
        version:        ApiSteward.normalize_version(detect_version(request)),
        client:         detect_client(request),
        path:           request.path,
        request_method: request.request_method
      )
    end

    private

    def detect_version(request)
      case @config.version_source
      when :header then request.get_header(@config.version_header_env)
      when :param  then request.params[@config.version_param]
      else version_from_path(request.path)
      end
    end

    def version_from_path(path)
      match = PATH_VERSION.match(path)
      match && match[1]
    end

    def detect_client(request)
      @config.identity.call(request)
    end
  end
end
