# frozen_string_literal: true

module ApiSteward
  # An ordered chain of identity strategies. Calling it runs each in turn and returns
  # the first Client a strategy produces. If none do, it returns an anonymous client,
  # so a caller is never left without an identity.
  class Identity
    # The default when nothing is configured: trust a Client the app left in the env,
    # otherwise treat the caller as anonymous.
    def self.default
      new([Strategies::FromEnv.new(CLIENT_ENV_KEY)])
    end

    def initialize(strategies)
      @strategies = strategies
    end

    def call(request)
      @strategies.each do |strategy|
        client = strategy.call(request)
        return client if client
      end
      Client.anonymous
    end

    # Collects strategies from an `identify do ... end` block.
    class Builder
      def initialize
        @strategies = []
      end

      def strategy(spec = nil, **options, &block)
        @strategies << Strategies.build(spec, **options, &block)
        self
      end

      def to_identity
        Identity.new(@strategies)
      end
    end
  end
end
