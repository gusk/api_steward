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
end
