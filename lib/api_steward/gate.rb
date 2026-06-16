# frozen_string_literal: true

module ApiSteward
  # The reason a request was turned away. `type` is the RFC 9457 problem-type URI.
  Block = Data.define(:status, :title, :detail, :type) do
    def initialize(status:, title:, detail:, type: "about:blank")
      super
    end
  end

  # Decides whether a request may proceed, given what we know about its version and who
  # is asking. Pure decision logic: it returns a Block to turn the request away, or nil
  # to let it through. No HTTP here.
  #
  # The clock is injectable so brownout windows are testable.
  class Gate
    def initialize(now: -> { Time.now })
      @now = now
    end

    def call(version, client)
      return nil unless version # a version we don't know isn't ours to police

      retired(version) || in_brownout(version) || internal_only(version, client)
    end

    private

    def retired(version)
      return unless version.gone?

      Block.new(status: 410, title: "API version retired",
                detail: "Version #{version.name} has been retired.")
    end

    def in_brownout(version)
      return unless version.in_brownout?(@now.call)

      Block.new(status: 503, title: "API version temporarily unavailable",
                detail: "Version #{version.name} is in a scheduled brownout.")
    end

    def internal_only(version, client)
      return unless version.internal?
      return if client.trusted && client.tier == :internal

      Block.new(status: 403, title: "API version is internal only",
                detail: "Version #{version.name} is restricted to internal callers.")
    end
  end
end
