# frozen_string_literal: true

require "test_helper"

class DashboardTest < Minitest::Test
  def setup
    @usage = ApiSteward::Usage.new
  end

  def get(path)
    ApiSteward::Dashboard.new(usage: @usage).call(Rack::MockRequest.env_for(path))
  end

  def test_renders_html_ok
    status, headers, _body = get("/")
    assert_equal 200, status
    assert_includes headers["content-type"], "text/html"
  end

  def test_empty_state_when_no_traffic
    assert_includes get("/").last.join, "No requests observed yet"
  end

  def test_shows_a_version_row
    @usage.record({ version: "v1", client_id: "acme" })
    body = get("/").last.join
    assert_includes body, "<table"
    assert_includes body, "v1"
  end

  def test_escapes_a_malicious_version_string
    @usage.record({ version: "<script>alert(1)</script>" })
    body = get("/").last.join
    refute_includes body, "<script>alert(1)</script>"
    assert_includes body, "&lt;script&gt;"
  end

  def test_unknown_path_is_404
    status, = get("/nope")
    assert_equal 404, status
  end
end
