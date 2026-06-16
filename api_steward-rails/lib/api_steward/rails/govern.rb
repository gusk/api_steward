# frozen_string_literal: true

require "api_steward"

module ApiSteward
  module Rails
    # Controller-level enforcement, for gates that depend on who is signed in.
    #
    #   class InternalController < ApplicationController
    #     include ApiSteward::Rails::Govern
    #     before_action :api_steward_govern!
    #   end
    #
    # Middleware Govern runs before your app authenticates, so it can't see current_user.
    # This before_action runs after authentication: it resolves the version and the
    # now-authenticated client, and renders an RFC 9457 problem document (halting the
    # request) if the version's lifecycle says it shouldn't proceed.
    module Govern
      private

      def api_steward_govern!(gate: ApiSteward::Gate.new)
        config = ApiSteward.config
        resolution = ApiSteward::Resolver.new(config).call(request)
        block = gate.call(config.version_info(resolution.version), resolution.client)
        return unless block

        _status, headers, body = ApiSteward::Problem.response(block, instance: request.path)
        render body: body.join, status: block.status, content_type: headers["content-type"]
      end
    end
  end
end
