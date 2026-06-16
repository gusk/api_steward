# frozen_string_literal: true

require "rack"

module ApiSteward
  # A minimal mountable Rack app. Right now it just renders a placeholder page; the
  # live version-usage views will build on the telemetry that Observe collects.
  #
  # Mount it wherever you assemble routes, e.g.:
  #
  #   map "/api_steward" { run ApiSteward::Dashboard }
  class Dashboard
    def self.call(env)
      new.call(env)
    end

    def call(_env)
      [200, { "content-type" => "text/html; charset=utf-8" }, [page]]
    end

    private

    def page
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head><meta charset="utf-8"><title>api_steward</title></head>
          <body>
            <h1>api_steward</h1>
            <p>The dashboard is under construction. Version usage will appear here.</p>
          </body>
        </html>
      HTML
    end
  end
end
