# frozen_string_literal: true

require "test_helper"

class UsageTest < Minitest::Test
  def setup
    @usage = ApiSteward::Usage.new
  end

  def event(version:, client_id: nil, status: 200)
    { version: version, client_id: client_id, tier: :external, status: status }
  end

  def test_ignores_events_without_a_version
    @usage.record(event(version: nil))
    assert_empty @usage.summary
  end

  def test_counts_requests_per_version
    3.times { @usage.record(event(version: "v1")) }
    @usage.record(event(version: "v2"))
    assert_equal 3, @usage.summary.find { |r| r.version == "v1" }.requests
  end

  def test_counts_distinct_clients_and_ignores_anonymous
    @usage.record(event(version: "v1", client_id: "acme"))
    @usage.record(event(version: "v1", client_id: "acme"))
    @usage.record(event(version: "v1", client_id: "globex"))
    @usage.record(event(version: "v1", client_id: nil))
    assert_equal 2, @usage.summary.first.clients
  end

  def test_sorts_busiest_version_first
    @usage.record(event(version: "v1"))
    2.times { @usage.record(event(version: "v2")) }
    assert_equal %w[v2 v1], @usage.summary.map(&:version)
  end

  def test_subscribe_to_tallies_only_request_events
    instrument = ApiSteward::Instrument.new
    @usage.subscribe_to(instrument)
    instrument.publish(ApiSteward::REQUEST_EVENT, event(version: "v1"))
    instrument.publish("some.other.event", event(version: "v9"))
    assert_equal ["v1"], @usage.summary.map(&:version)
  end
end
