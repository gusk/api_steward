# frozen_string_literal: true

module ApiSteward
  # A declared API version and its lifecycle state.
  #
  # `deprecation_on` and `sunset_on` are Times (or nil). They drive the Stage 1 signal
  # headers: Deprecation (RFC 9745) and Sunset (RFC 8594). `link` is an optional URL
  # describing the deprecation, sent as a Link header.
  ApiVersion = Data.define(:name, :status, :deprecation_on, :sunset_on, :link) do
    def initialize(name:, status: :active, deprecation_on: nil, sunset_on: nil, link: nil)
      super(name: name.to_s, status: status, deprecation_on: deprecation_on,
            sunset_on: sunset_on, link: link)
    end

    def active?
      status == :active
    end

    # Should we send a Deprecation header for this version?
    def signals_deprecation?
      !deprecation_on.nil?
    end

    # Should we send a Sunset header for this version?
    def signals_sunset?
      !sunset_on.nil?
    end
  end
end
