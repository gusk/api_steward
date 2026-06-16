# frozen_string_literal: true

require "test_helper"

class IdentityTest < Minitest::Test
  def build_identity(&block)
    config = ApiSteward::Configuration.new
    config.identify(&block)
    config.identity
  end

  def request(path = "/x", env = {})
    Rack::Request.new(Rack::MockRequest.env_for(path, env))
  end

  def test_default_reads_a_client_the_app_left_in_the_env
    identity = ApiSteward::Configuration.new.identity
    client = ApiSteward::Client.new(id: "acme", trusted: true)
    assert_same client, identity.call(request("/x", "api_steward.client" => client))
  end

  def test_default_falls_back_to_anonymous
    assert ApiSteward::Configuration.new.identity.call(request).anonymous?
  end

  def test_first_matching_strategy_wins
    identity = build_identity do
      strategy ->(_r) { nil }
      strategy ->(_r) { ApiSteward::Client.new(id: "first", trusted: true) }
      strategy ->(_r) { ApiSteward::Client.new(id: "second", trusted: true) }
    end
    assert_equal "first", identity.call(request).id
  end

  def test_anonymous_floor_when_nothing_matches
    identity = build_identity { strategy ->(_r) { nil } }
    assert identity.call(request).anonymous?
  end

  def test_api_key_without_a_lookup_is_attribution_only
    identity = build_identity { strategy :from_api_key, header: "X-Api-Key" }
    client = identity.call(request("/x", "HTTP_X_API_KEY" => "abc123"))
    assert_equal "abc123", client.id
    refute client.trusted, "an unverified key must never be trusted"
  end

  def test_api_key_with_a_lookup_decides_trust
    identity = build_identity do
      strategy :from_api_key, header: "X-Api-Key" do |key|
        ApiSteward::Client.new(id: "acme", tier: :internal, trusted: true) if key == "good"
      end
    end
    assert_equal "acme", identity.call(request("/x", "HTTP_X_API_KEY" => "good")).id
    assert identity.call(request("/x", "HTTP_X_API_KEY" => "bad")).anonymous?
  end

  def test_ip_strategy_marks_internal_ranges_trusted
    identity = build_identity { strategy :from_ip, internal: ["10.0.0.0/8"] }
    client = identity.call(request("/x", "REMOTE_ADDR" => "10.1.2.3"))
    assert client.trusted
    assert_equal :internal, client.tier
  end

  def test_ip_strategy_ignores_addresses_outside_the_ranges
    identity = build_identity { strategy :from_ip, internal: ["10.0.0.0/8"] }
    assert identity.call(request("/x", "REMOTE_ADDR" => "8.8.8.8")).anonymous?
  end

  def test_unknown_strategy_name_is_rejected
    assert_raises(ArgumentError) { build_identity { strategy :nope } }
  end
end
