# frozen_string_literal: true

module ApiSteward
  # Rack env keys api_steward reads and writes.
  CLIENT_ENV_KEY     = "api_steward.client"
  RESOLUTION_ENV_KEY = "api_steward.resolution"

  # The instrumentation event published for each observed request.
  REQUEST_EVENT = "api_steward.request"
end
