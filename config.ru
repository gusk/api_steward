# frozen_string_literal: true

# A tiny runnable example. With the dev dependencies installed:
#
#   bundle exec rackup
#
# then make a few requests and watch the attribution print to your terminal:
#
#   curl localhost:9292/api/v1/widgets
#   curl localhost:9292/api/v2/widgets
#   open  localhost:9292/api_steward    # the (placeholder) dashboard

require "api_steward"

ApiSteward.configure do |c|
  c.version_from :path

  # Declare versions and their lifecycle.
  c.version "v0", status: :gone                                  # retired -> 410
  c.version "v1", status: :deprecated, sunset: "2026-11-11",     # on its way out
            link: "https://example.com/deprecations/v1"
  c.version "v2"                                                 # active
end

# Print each observed request, so you can see version + client attribution happen.
ApiSteward.instrument.subscribe do |_event, p|
  warn "[api_steward] #{p[:method]} #{p[:path]} -> " \
       "version=#{p[:version]} client=#{p[:client_id].inspect} status=#{p[:status]}"
end

ApiSteward.usage # start tallying now, so the dashboard sees traffic from boot

use ApiSteward::Observe
use ApiSteward::Govern
use ApiSteward::Signal

map "/api_steward" do
  run ApiSteward::Dashboard
end

map "/" do
  run lambda { |env|
    path = Rack::Request.new(env).path
    [200, { "content-type" => "text/plain" }, ["hello from #{path}\n"]]
  }
end
