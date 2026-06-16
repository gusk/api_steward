# frozen_string_literal: true

module ApiSteward
  # What we learned about a request: which version it targets and who made it.
  Resolution = Data.define(:version, :client, :path)

  # Turns a Rack request into a Resolution.
  #
  # Version detection follows the configuration. Client identification is best-effort
  # at this stage: if the app has set `env["api_steward.client"]`, we use it; otherwise
  # the caller is treated as anonymous. (Trusted identity for enforcement comes later.)
  class Resolver
    CLIENT_ENV_KEY = "api_steward.client"
    PATH_VERSION = /\Av\d+\z/i

    def initialize(config)
      @config = config
    end

    def call(request)
      Resolution.new(
        version: detect_version(request),
        client:  detect_client(request),
        path:    request.path
      )
    end

    private

    def detect_version(request)
      case @config.version_source
      when :header then request.get_header(header_env_key(@config.version_header))
      when :param  then request.params[@config.version_param]
      else version_from_path(request.path)
      end
    end

    def version_from_path(path)
      segment = path.split("/").find { |s| s.match?(PATH_VERSION) }
      segment&.downcase
    end

    def header_env_key(name)
      "HTTP_#{name.upcase.tr("-", "_")}"
    end

    def detect_client(request)
      request.get_header(CLIENT_ENV_KEY) || Client.anonymous
    end
  end
end
