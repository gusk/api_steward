# frozen_string_literal: true

require "time"
require "date"

module ApiSteward
  # Holds how api_steward should read a request, and what it knows about each version.
  #
  # An instance can be created and passed explicitly (handy for tests or running more
  # than one), or the global one set up via ApiSteward.configure can be used.
  class Configuration
    attr_reader :version_source, :version_header, :version_param

    def initialize
      @version_source = :path
      @version_header = "X-Api-Version"
      @version_param  = "version"
      @versions = {}.freeze
    end

    # Tell api_steward where to find the API version in a request.
    #
    #   version_from :path                            # /api/v1/...
    #   version_from :header, name: "X-Api-Version"
    #   version_from :param,  name: "version"
    def version_from(source, name: nil)
      @version_source = source
      case source
      when :header then @version_header = name if name
      when :param  then @version_param  = name if name
      end
      self
    end

    # Declare a version and its lifecycle. Dates may be a Time, Date, epoch Integer, or
    # a parseable String. Brownouts are a Range of times, or an array of Ranges.
    #
    #   version "v1", status: :deprecated, sunset: "2026-11-11"
    #   version "v2", access: :internal
    #   version "v0", status: :gone
    #   version "v3", brownouts: Time.utc(2026, 7, 1, 9)..Time.utc(2026, 7, 1, 9, 15)
    def version(name, status: :active, deprecation: nil, sunset: nil, link: nil,
                access: :public, brownouts: nil)
      deprecation ||= Time.now if status == :deprecated
      info = ApiVersion.new(
        name: ApiSteward.normalize_version(name),
        status: status,
        deprecation_on: coerce_time(deprecation),
        sunset_on: coerce_time(sunset),
        link: link,
        access: access,
        brownouts: coerce_brownouts(brownouts)
      )
      @versions = @versions.merge(info.name => info).freeze
      info
    end

    # The declared version, or nil if we know nothing about it.
    def version_info(name)
      @versions[ApiSteward.normalize_version(name)]
    end

    # Configure how to identify the client behind a request. Strategies are tried in
    # order; the first to return a Client wins.
    #
    #   identify do
    #     strategy :from_env, key: "api_steward.client"
    #     strategy :from_api_key, header: "X-Api-Key" do |key| ... end
    #     strategy :from_ip, internal: ["10.0.0.0/8"]
    #     strategy :anonymous
    #   end
    def identify(&block)
      builder = Identity::Builder.new
      builder.instance_eval(&block) if block
      @identity = builder.to_identity
      self
    end

    # The identity chain (a default that reads env, then anonymous, until configured).
    def identity
      @identity ||= Identity.default
    end

    private

    DATE_ONLY = /\A\d{4}-\d{2}-\d{2}\z/

    # A bare date (a "2026-11-11" string or a Date) is read as UTC midnight, so the
    # Sunset/Deprecation headers are predictable regardless of the server's timezone.
    # A string with an explicit time or zone is taken at its word.
    def coerce_time(value)
      case value
      when nil     then nil
      when Time    then value
      when Date    then Time.utc(value.year, value.month, value.day)
      when Integer then Time.at(value)
      when String
        value.match?(DATE_ONLY) ? Time.utc(*value.split("-").map(&:to_i)) : Time.parse(value)
      else raise ArgumentError, "can't read #{value.inspect} as a time"
      end
    end

    def coerce_brownouts(value)
      windows = case value
                when nil   then []
                when Range then [value]
                else value
                end
      windows.map { |w| coerce_time(w.begin)..coerce_time(w.end) }.freeze
    end
  end
end
