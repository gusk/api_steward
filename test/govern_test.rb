# frozen_string_literal: true

require "test_helper"

class GovernTest < Minitest::Test
  def setup
    ApiSteward.reset!
    ApiSteward.configure { |c| c.version_from :path }
  end

  def teardown
    ApiSteward.reset!
  end

  def ok_app
    ->(_env) { [200, { "content-type" => "text/plain" }, ["ok"]] }
  end

  def call(path, app: ok_app, env: {})
    e = Rack::MockRequest.env_for(path)
    env.each { |k, v| e[k] = v }
    ApiSteward::Govern.new(app).call(e)
  end

  def test_allows_an_active_version
    ApiSteward.config.version("v1")
    assert_equal 200, call("/api/v1/x").first
  end

  def test_allows_an_unknown_version
    assert_equal 200, call("/api/v9/x").first
  end

  def test_blocks_a_gone_version_with_problem_json
    ApiSteward.config.version("v1", status: :gone)
    status, headers, body = call("/api/v1/x")
    assert_equal 410, status
    assert_equal "application/problem+json", headers["content-type"]
    assert_equal "/api/v1/x", JSON.parse(body.join)["instance"]
  end

  def test_blocks_an_external_caller_from_an_internal_version
    ApiSteward.config.version("v1", access: :internal)
    assert_equal 403, call("/api/v1/x").first # anonymous == external
  end

  def test_allows_a_trusted_internal_caller
    ApiSteward.config.version("v1", access: :internal)
    internal = ApiSteward::Client.new(id: "svc", tier: :internal, trusted: true)
    assert_equal 200, call("/api/v1/x", env: { "api_steward.client" => internal }).first
  end

  def test_does_not_reach_the_app_when_blocked
    ApiSteward.config.version("v1", status: :gone)
    reached = false
    call("/api/v1/x", app: ->(_env) { reached = true; [200, {}, ["ok"]] })
    refute reached, "a blocked request must not reach the app"
  end

  def test_fails_open_when_its_own_logic_raises
    boom = Object.new
    def boom.resolve(_env) = raise("nope")
    status, = ApiSteward::Govern.new(ok_app, resolver: boom).call(Rack::MockRequest.env_for("/api/v1/x"))
    assert_equal 200, status # request still served
  end
end
