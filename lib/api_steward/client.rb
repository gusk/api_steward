# frozen_string_literal: true

module ApiSteward
  # A resolved API client.
  #
  # `trusted` records whether the identity was established by a means we can rely on
  # for access decisions. Telemetry uses the client regardless of `trusted`; only
  # enforcement (a later stage) insists on it.
  Client = Data.define(:id, :tier, :trusted, :meta) do
    # A known-anonymous caller. Anonymity is a definite state, so it counts as trusted.
    # Anonymous is an immutable value, so the common (external) case is memoized to
    # avoid allocating one on every anonymous request.
    def self.anonymous(tier: :external)
      if tier == :external
        @anonymous ||= new(id: nil, tier: :external, trusted: true, meta: {})
      else
        new(id: nil, tier: tier, trusted: true, meta: {})
      end
    end

    def initialize(id:, tier: :external, trusted: false, meta: {})
      super(id: id, tier: tier, trusted: trusted, meta: meta.freeze)
    end

    def anonymous?
      id.nil?
    end
  end
end
