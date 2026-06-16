# frozen_string_literal: true

require "test_helper"

class SignalTest < Minitest::Test
  def setup
    ApiSteward.reset!
    ApiSteward.configure { |c| c.version_from :path }
  end

  def teardown
    ApiSteward.reset!
  end

  def app(headers = {})
    ->(_env) { [200, headers.dup, ["ok"]] }
  end

  def call(path, response_headers = {})
    ApiSteward::Signal.new(app(response_headers)).call(Rack::MockRequest.env_for(path))
  end

  def test_no_headers_for_an_active_version
    ApiSteward.config.version("v1")
    _s, headers, _b = call("/api/v1/x")
    refute headers.key?("deprecation")
    refute headers.key?("sunset")
  end

  def test_no_headers_for_an_unknown_version
    _s, headers, _b = call("/api/v9/x")
    refute headers.key?("deprecation")
    refute headers.key?("sunset")
  end

  def test_adds_deprecation_header_as_an_sf_date
    ApiSteward.config.version("v1", deprecation: Time.at(1_700_000_000))
    _s, headers, _b = call("/api/v1/x")
    assert_equal "@1700000000", headers["deprecation"]
  end

  def test_adds_sunset_header_as_an_http_date
    sunset = Time.at(1_700_000_000)
    ApiSteward.config.version("v1", sunset: sunset)
    _s, headers, _b = call("/api/v1/x")
    assert_equal sunset.httpdate, headers["sunset"]
  end

  def test_adds_a_deprecation_link_when_given
    ApiSteward.config.version("v1", status: :deprecated, link: "https://example.com/deprecations/v1")
    _s, headers, _b = call("/api/v1/x")
    assert_includes headers["link"], %(rel="deprecation")
    assert_includes headers["link"], "https://example.com/deprecations/v1"
  end

  def test_appends_to_an_existing_link_header
    ApiSteward.config.version("v1", status: :deprecated, link: "https://example.com/d")
    _s, headers, _b = call("/api/v1/x", { "link" => %(<https://example.com/self>; rel="self") })
    assert_includes headers["link"], %(rel="self")
    assert_includes headers["link"], %(rel="deprecation")
  end

  def test_passes_the_response_through_when_there_is_no_version
    status, headers, body = call("/healthz")
    assert_equal 200, status
    assert_empty headers
    assert_equal ["ok"], body
  end

  def test_never_breaks_the_request_when_signaling_fails
    raising = Object.new
    def raising.resolve(_env) = raise("nope")
    status, = ApiSteward::Signal.new(app, resolver: raising).call(Rack::MockRequest.env_for("/api/v1/x"))
    assert_equal 200, status
  end
end
