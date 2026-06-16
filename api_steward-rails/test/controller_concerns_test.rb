# frozen_string_literal: true

require "test_helper"
require "rack/mock"

# A tiny stand-in for an Action Controller — just enough to exercise the concerns
# (a class-level before_action recorder, a request, params, and render) without pulling
# in the full Action Pack request lifecycle.
class FakeController
  def self.before_action(name, **_options)
    registered_before_actions << name
  end

  def self.registered_before_actions
    @registered_before_actions ||= []
  end

  attr_reader :request, :rendered
  attr_accessor :params

  def initialize(env)
    @request = Rack::Request.new(env)
    @params = {}
  end

  def render(**options)
    @rendered = options
  end
end

class IdentifyConcernTest < Minitest::Test
  class Controller < FakeController
    include ApiSteward::Rails::Identify

    api_steward_identify do
      next unless params[:as_internal]
      ApiSteward::Client.new(id: "u1", tier: :internal, trusted: true)
    end
  end

  def controller(params: {})
    c = Controller.new(Rack::MockRequest.env_for("/api/v1/x"))
    c.params = params
    c
  end

  def test_registers_a_before_action
    assert_includes Controller.registered_before_actions, :api_steward_set_client
  end

  def test_sets_the_client_from_the_block
    c = controller(params: { as_internal: true })
    c.send(:api_steward_set_client)
    client = c.request.get_header(ApiSteward::CLIENT_ENV_KEY)
    assert_equal "u1", client.id
    assert_equal :internal, client.tier
    assert client.trusted
  end

  def test_leaves_the_caller_anonymous_when_the_block_returns_nil
    c = controller(params: {})
    c.send(:api_steward_set_client)
    assert_nil c.request.get_header(ApiSteward::CLIENT_ENV_KEY)
  end
end

class GovernConcernTest < Minitest::Test
  class Controller < FakeController
    include ApiSteward::Rails::Govern
  end

  def setup
    ApiSteward.reset!
    ApiSteward.configure { |c| c.version_from :path }
  end

  def teardown
    ApiSteward.reset!
  end

  def govern(path = "/api/v1/x", client: nil)
    env = Rack::MockRequest.env_for(path)
    env[ApiSteward::CLIENT_ENV_KEY] = client if client
    c = Controller.new(env)
    c.send(:api_steward_govern!)
    c
  end

  def test_allows_an_active_version
    ApiSteward.config.version("v1")
    assert_nil govern.rendered, "an allowed request should not be rendered/halted"
  end

  def test_allows_an_unknown_version
    assert_nil govern("/api/v9/x").rendered
  end

  def test_blocks_a_gone_version_with_problem_json
    ApiSteward.config.version("v1", status: :gone)
    rendered = govern.rendered
    assert_equal 410, rendered[:status]
    assert_equal "application/problem+json", rendered[:content_type]
    assert_equal 410, JSON.parse(rendered[:body])["status"]
  end

  def test_blocks_an_external_caller_from_an_internal_version
    ApiSteward.config.version("v1", access: :internal)
    assert_equal 403, govern.rendered[:status] # anonymous == external
  end

  def test_allows_a_trusted_internal_caller_set_by_identify
    ApiSteward.config.version("v1", access: :internal)
    internal = ApiSteward::Client.new(id: "svc", tier: :internal, trusted: true)
    assert_nil govern(client: internal).rendered
  end
end
