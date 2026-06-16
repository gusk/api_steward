# frozen_string_literal: true

require "test_helper"

class InstrumentTest < Minitest::Test
  def setup
    @hub = ApiSteward::Instrument.new
  end

  def test_publishes_to_subscribers
    seen = []
    @hub.subscribe { |name, payload| seen << [name, payload] }
    @hub.publish("evt", { a: 1 })
    assert_equal [["evt", { a: 1 }]], seen
  end

  def test_a_failing_subscriber_does_not_affect_others_or_the_caller
    @hub.subscribe { raise "boom" }
    ok = []
    @hub.subscribe { |name, _payload| ok << name }
    @hub.publish("evt") # must not raise
    assert_equal ["evt"], ok
  end

  def test_subscribe_requires_something_callable
    assert_raises(ArgumentError) { @hub.subscribe("not callable") }
  end

  def test_empty_until_someone_subscribes
    assert @hub.empty?
    @hub.subscribe { |_n, _p| }
    refute @hub.empty?
  end

  def test_does_not_build_a_payload_when_no_one_is_listening
    built = false
    @hub.publish("evt") { built = true; {} }
    refute built, "the payload block must not run without subscribers"
  end

  def test_builds_the_payload_once_for_subscribers
    seen = []
    @hub.subscribe { |_n, payload| seen << payload }
    calls = 0
    @hub.publish("evt") { calls += 1; { n: calls } }
    assert_equal 1, calls
    assert_equal [{ n: 1 }], seen
  end
end
