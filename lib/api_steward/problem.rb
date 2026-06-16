# frozen_string_literal: true

require "json"

module ApiSteward
  # Turns a Block into an RFC 9457 (application/problem+json) Rack response. Formatting
  # only — it decides nothing.
  module Problem
    module_function

    def response(block, instance:)
      document = {
        type:     block.type,
        title:    block.title,
        status:   block.status,
        detail:   block.detail,
        instance: instance
      }.compact

      [block.status,
       { "content-type" => "application/problem+json" },
       [JSON.generate(document)]]
    end
  end
end
