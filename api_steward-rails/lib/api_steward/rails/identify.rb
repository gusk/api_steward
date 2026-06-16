# frozen_string_literal: true

require "active_support/concern"
require "api_steward"

module ApiSteward
  module Rails
    # Bridges your app's authenticated identity into api_steward.
    #
    #   class ApplicationController < ActionController::API
    #     include ApiSteward::Rails::Identify
    #
    #     api_steward_identify do
    #       next unless current_user
    #       ApiSteward::Client.new(id: current_user.id,
    #                              tier: current_user.staff? ? :internal : :external,
    #                              trusted: true)
    #     end
    #   end
    #
    # The block runs as a before_action in the controller's context (so current_user and
    # friends are available) and its result is stored in the Rack env, where Observe,
    # Signal, and the identity chain's :from_env strategy pick it up. Returning nil leaves
    # the caller anonymous.
    module Identify
      extend ActiveSupport::Concern

      included do
        before_action :api_steward_set_client
      end

      class_methods do
        def api_steward_identify(&block)
          @api_steward_identifier = block
        end

        # Walks up the inheritance chain, so declaring it once in ApplicationController
        # covers every controller below it.
        def api_steward_identifier
          return @api_steward_identifier if defined?(@api_steward_identifier) && @api_steward_identifier

          superclass.respond_to?(:api_steward_identifier) ? superclass.api_steward_identifier : nil
        end
      end

      private

      def api_steward_set_client
        block = self.class.api_steward_identifier or return

        client = instance_exec(&block)
        request.set_header(ApiSteward::CLIENT_ENV_KEY, client) if client
      end
    end
  end
end
