# frozen_string_literal: true

require "rack"

module ApiSteward
  # A small mountable Rack app that shows live version usage.
  #
  # Its job is the HTTP request and the routing; the counting lives in Usage and the
  # HTML lives in Dashboard::View.
  #
  #   map "/api_steward" { run ApiSteward::Dashboard }
  class Dashboard
    def self.call(env)
      (@instance ||= new).call(env)
    end

    def initialize(usage: nil)
      @usage = usage
    end

    def call(env)
      case Rack::Request.new(env).path_info
      when "", "/" then ok(View.new(rows: usage.summary, generated_at: Time.now).to_html)
      else not_found
      end
    end

    private

    def usage
      @usage || ApiSteward.usage
    end

    def ok(body)
      [200, { "content-type" => "text/html; charset=utf-8" }, [body]]
    end

    def not_found
      [404, { "content-type" => "text/plain; charset=utf-8" }, ["Not found"]]
    end
  end
end
