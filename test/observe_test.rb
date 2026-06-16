# frozen_string_literal: true

require "test_helper"

class ObserveTest < Minitest::Test
  def setup
    ApiSteward.reset!
    ApiSteward.configure { |c| c.version_from :path }
    @events = []
    ApiSteward.instrument.subscribe { |name, payload| @events << payload.merge(event: name) }
  end

  def teardown
    ApiSteward.reset!
  end

  def stack(app = ->(_env) { [200, {}, ["ok"]] }, **opts)
    ApiSteward::Observe.new(app, **opts)
  end

  def test_passes_the_response_through_unchanged
    app = ->(_env) { [201, { "x" => "y" }, ["body"]] }
    status, headers, body = stack(app).call(Rack::MockRequest.env_for("/api/v1/x"))
    assert_equal 201, status
    assert_equal({ "x" => "y" }, headers)
    assert_equal ["body"], body
  end

  def test_records_version_method_and_status
    stack.call(Rack::MockRequest.env_for("/api/v1/users"))
    assert_equal 1, @events.length
    e = @events.first
    assert_equal "v1", e[:version]
    assert_equal 200, e[:status]
    assert_equal "GET", e[:method]
  end

  def test_does_not_record_requests_without_a_version
    stack.call(Rack::MockRequest.env_for("/healthz"))
    assert_empty @events
  end

  def test_uses_the_client_the_app_supplied
    env = Rack::MockRequest.env_for("/api/v2/x")
    env["api_steward.client"] = ApiSteward::Client.new(id: "acme", tier: :internal, trusted: true)
    stack.call(env)
    assert_equal "acme", @events.first[:client_id]
    assert_equal :internal, @events.first[:tier]
  end

  def test_never_breaks_the_request_when_bookkeeping_fails
    raising = Object.new
    def raising.call(_request) = raise("kaboom")

    status, = stack(resolver: raising).call(Rack::MockRequest.env_for("/api/v1/x"))
    assert_equal 200, status # the request is still served
    assert_empty @events     # nothing recorded, but nothing crashed either
  end
end
