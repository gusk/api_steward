# frozen_string_literal: true

module ApiSteward
  # A declared API version and its lifecycle state.
  #
  # The dates (deprecation_on, sunset_on) drive the Stage 1 signal headers. `status`,
  # `access`, and `brownouts` drive Stage 2 enforcement.
  ApiVersion = Data.define(:name, :status, :deprecation_on, :sunset_on, :link, :access, :brownouts) do
    def initialize(name:, status: :active, deprecation_on: nil, sunset_on: nil,
                   link: nil, access: :public, brownouts: [])
      super(name: name.to_s, status: status, deprecation_on: deprecation_on,
            sunset_on: sunset_on, link: link, access: access, brownouts: brownouts.freeze)
    end

    def active?
      status == :active
    end

    def gone?
      status == :gone
    end

    def internal?
      access == :internal
    end

    def in_brownout?(now)
      brownouts.any? { |window| window.cover?(now) }
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
