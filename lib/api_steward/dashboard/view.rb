# frozen_string_literal: true

require "erb"

module ApiSteward
  class Dashboard
    # Renders the usage summary to HTML. Rendering only — no data gathering, no HTTP.
    #
    # Version names come from request input, so they are always HTML-escaped (via `h`)
    # to keep an odd version string from turning into stored markup in the page.
    class View
      include ERB::Util # provides h() for escaping

      TEMPLATE = <<~ERB
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>api_steward</title>
          <style>
            body { font: 14px -apple-system, system-ui, sans-serif; margin: 2rem; color: #1a1a1a; }
            h1 { font-size: 1.25rem; }
            table { border-collapse: collapse; margin-top: 1rem; min-width: 30rem; }
            th, td { text-align: left; padding: 0.4rem 0.85rem; border-bottom: 1px solid #eee; }
            th { font-weight: 600; color: #555; }
            td.num { text-align: right; font-variant-numeric: tabular-nums; }
            .empty { color: #777; margin-top: 1rem; }
            footer { margin-top: 1.5rem; color: #999; font-size: 12px; }
          </style>
        </head>
        <body>
          <h1>api_steward &middot; version usage</h1>
          <% if rows.empty? -%>
          <p class="empty">No requests observed yet.</p>
          <% else -%>
          <table>
            <thead>
              <tr><th>Version</th><th>Requests</th><th>Clients</th><th>Last seen</th></tr>
            </thead>
            <tbody>
              <% rows.each do |row| -%>
              <tr>
                <td><%= h row.version %></td>
                <td class="num"><%= row.requests %></td>
                <td class="num"><%= row.clients %></td>
                <td><%= row.last_seen ? row.last_seen.utc.strftime("%Y-%m-%d %H:%M:%S UTC") : "—" %></td>
              </tr>
              <% end -%>
            </tbody>
          </table>
          <% end -%>
          <footer>generated <%= generated_at.utc.strftime("%Y-%m-%d %H:%M:%S UTC") %></footer>
        </body>
        </html>
      ERB

      def initialize(rows:, generated_at:)
        @rows = rows
        @generated_at = generated_at
      end

      def to_html
        ERB.new(TEMPLATE, trim_mode: "-").result(binding)
      end

      private

      attr_reader :rows, :generated_at
    end
  end
end
