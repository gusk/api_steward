# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  def test_anonymous_has_no_id_and_is_trusted
    c = ApiSteward::Client.anonymous
    assert_nil c.id
    assert c.anonymous?
    assert c.trusted, "anonymity is a definite state, so it counts as trusted"
    assert_equal :external, c.tier
  end

  def test_explicit_client_defaults_to_untrusted
    c = ApiSteward::Client.new(id: "acme")
    refute c.trusted
    refute c.anonymous?
    assert_equal :external, c.tier
  end

  def test_meta_is_frozen
    c = ApiSteward::Client.new(id: "x", meta: { name: "X" })
    assert c.meta.frozen?
  end
end
