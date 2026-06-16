# frozen_string_literal: true

require "set"

module ApiSteward
  # A live, in-memory tally of observed requests, grouped by version. Subscribe it to
  # an instrument and it accumulates counts as REQUEST_EVENTs arrive; the dashboard
  # reads from it. Thread-safe.
  #
  # Its one job is counting. It doesn't keep raw events, render anything, or persist —
  # those belong elsewhere.
  class Usage
    # One version's tally, shaped the way the dashboard wants to read it.
    Row = Data.define(:version, :requests, :clients, :last_seen)

    def initialize
      @mutex = Mutex.new
      @buckets = {}
    end

    # Wire this tally to an instrument and return self.
    def subscribe_to(instrument)
      instrument.subscribe do |event, payload|
        record(payload) if event == REQUEST_EVENT
      end
      self
    end

    def record(payload)
      version = payload[:version]
      return unless version

      @mutex.synchronize do
        bucket = (@buckets[version] ||= { requests: 0, clients: Set.new, last_seen: nil })
        bucket[:requests] += 1
        bucket[:clients] << payload[:client_id] unless payload[:client_id].nil?
        bucket[:last_seen] = Time.now
      end
    end

    # Rows, busiest version first.
    def summary
      rows = @mutex.synchronize do
        @buckets.map do |version, b|
          Row.new(version: version, requests: b[:requests],
                  clients: b[:clients].size, last_seen: b[:last_seen])
        end
      end
      rows.sort_by { |row| -row.requests }
    end

    def reset
      @mutex.synchronize { @buckets.clear }
    end
  end
end
