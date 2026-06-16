# frozen_string_literal: true

module ApiSteward
  # A small instrumentation hub. Subscribers are anything that responds to #call with
  # (event_name, payload). It is intentionally tiny and dependency-free; an optional
  # bridge can forward these events to ActiveSupport::Notifications for apps that use it.
  #
  # Publishing never raises into the caller: a misbehaving subscriber is isolated so it
  # can't break the request path.
  class Instrument
    def initialize
      @subscribers = [].freeze
      @mutex = Mutex.new
    end

    # Register a subscriber. Pass a callable or a block.
    def subscribe(callable = nil, &block)
      sub = callable || block
      unless sub.respond_to?(:call)
        raise ArgumentError, "subscribe expects a callable or a block"
      end
      @mutex.synchronize { @subscribers = (@subscribers + [sub]).freeze }
      sub
    end

    def publish(event, payload = {})
      @subscribers.each do |sub|
        sub.call(event, payload)
      rescue StandardError
        # One subscriber's failure must not affect the request or other subscribers.
      end
    end
  end
end
