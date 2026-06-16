# frozen_string_literal: true

require "test_helper"

class ProblemTest < Minitest::Test
  def test_builds_a_problem_json_response
    block = ApiSteward::Block.new(status: 410, title: "Gone", detail: "Bye.")
    status, headers, body = ApiSteward::Problem.response(block, instance: "/api/v1/x")

    assert_equal 410, status
    assert_equal "application/problem+json", headers["content-type"]

    doc = JSON.parse(body.join)
    assert_equal 410, doc["status"]
    assert_equal "Gone", doc["title"]
    assert_equal "Bye.", doc["detail"]
    assert_equal "/api/v1/x", doc["instance"]
    assert_equal "about:blank", doc["type"]
  end

  def test_omits_blank_fields
    block = ApiSteward::Block.new(status: 503, title: "Down", detail: nil)
    _s, _h, body = ApiSteward::Problem.response(block, instance: "/x")
    refute JSON.parse(body.join).key?("detail")
  end
end
