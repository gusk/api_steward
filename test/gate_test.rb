# frozen_string_literal: true

require "test_helper"

class GateTest < Minitest::Test
  def gate(now: -> { Time.now })
    ApiSteward::Gate.new(now: now)
  end

  def version(**opts)
    ApiSteward::Configuration.new.version("v1", **opts)
  end

  def client(tier: :external, trusted: false)
    ApiSteward::Client.new(id: "c", tier: tier, trusted: trusted)
  end

  def anonymous
    ApiSteward::Client.anonymous
  end

  def test_unknown_version_is_allowed
    assert_nil gate.call(nil, anonymous)
  end

  def test_active_public_version_is_allowed
    assert_nil gate.call(version, anonymous)
  end

  def test_gone_version_is_blocked_with_410
    assert_equal 410, gate.call(version(status: :gone), anonymous).status
  end

  def test_internal_version_blocks_an_external_caller
    assert_equal 403, gate.call(version(access: :internal), client(tier: :external, trusted: true)).status
  end

  def test_internal_version_refuses_an_untrusted_internal_claim
    block = gate.call(version(access: :internal), client(tier: :internal, trusted: false))
    assert_equal 403, block.status, "an unverified 'internal' claim must not pass"
  end

  def test_internal_version_allows_a_trusted_internal_caller
    assert_nil gate.call(version(access: :internal), client(tier: :internal, trusted: true))
  end

  def test_brownout_blocks_during_the_window
    now = Time.at(1_000)
    block = gate(now: -> { now }).call(version(brownouts: Time.at(900)..Time.at(1_100)), anonymous)
    assert_equal 503, block.status
  end

  def test_brownout_allows_outside_the_window
    now = Time.at(2_000)
    assert_nil gate(now: -> { now }).call(version(brownouts: Time.at(900)..Time.at(1_100)), anonymous)
  end
end
