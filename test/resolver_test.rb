# frozen_string_literal: true

require "test_helper"

class ResolverTest < Minitest::Test
  def resolver(source: :path, name: nil)
    config = ApiSteward::Configuration.new
    config.version_from(source, name: name)
    ApiSteward::Resolver.new(config)
  end

  def req(path, env = {})
    Rack::Request.new(Rack::MockRequest.env_for(path, env))
  end

  def test_detects_version_from_path
    assert_equal "v1", resolver.call(req("/api/v1/users")).version
  end

  def test_no_version_when_path_has_none
    assert_nil resolver.call(req("/healthz")).version
  end

  def test_detects_version_from_header
    r = resolver(source: :header, name: "X-Api-Version")
    assert_equal "v3", r.call(req("/x", "HTTP_X_API_VERSION" => "v3")).version
  end

  def test_client_is_anonymous_by_default
    assert resolver.call(req("/api/v1/x")).client.anonymous?
  end

  def test_uses_client_supplied_in_env
    env = Rack::MockRequest.env_for("/api/v1/x")
    env["api_steward.client"] = ApiSteward::Client.new(id: "acme", trusted: true)
    assert_equal "acme", resolver.call(Rack::Request.new(env)).client.id
  end

  def test_captures_the_request_method
    assert_equal "GET", resolver.call(req("/api/v1/x")).request_method
  end

  def test_resolve_caches_the_result_in_the_env
    env = Rack::MockRequest.env_for("/api/v1/x")
    r = resolver
    first = r.resolve(env)
    assert_same first, r.resolve(env)
    assert_same first, env[ApiSteward::RESOLUTION_ENV_KEY]
  end
end
