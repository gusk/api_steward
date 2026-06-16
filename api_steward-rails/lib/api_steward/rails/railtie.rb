# frozen_string_literal: true

# railties' rails/initializable uses delegate_missing_to at load time, but rails/railtie
# only requires that core extension afterwards. Loading it first lets the shim be
# required on its own (e.g. in tests) without a full Rails boot already in place.
require "active_support"
require "active_support/core_ext/module/delegation"

require "rails/railtie"
require "active_support/ordered_options"
require "active_support/notifications"
require "api_steward"

module ApiSteward
  module Rails
    # Wires api_steward into a Rails app: inserts the middleware you've enabled and,
    # optionally, forwards events to ActiveSupport::Notifications.
    #
    # Configure in config/application.rb or an initializer:
    #
    #   config.api_steward.observe = true        # default — record version usage
    #   config.api_steward.signal  = true        # add deprecation/sunset headers
    #   config.api_steward.govern  = true        # enforce gone / internal / brownout
    #   config.api_steward.notifications = true  # re-emit on ActiveSupport::Notifications
    class Railtie < ::Rails::Railtie
      config.api_steward = ActiveSupport::OrderedOptions.new
      config.api_steward.observe = true
      config.api_steward.signal  = false
      config.api_steward.govern  = false
      config.api_steward.notifications = false

      initializer "api_steward.middleware" do |app|
        options = app.config.api_steward
        # Order matters: Observe wraps everything (so it records blocked requests too),
        # Govern can stop a request, and Signal annotates whatever gets through.
        app.middleware.use ApiSteward::Observe if options.observe
        app.middleware.use ApiSteward::Govern  if options.govern
        app.middleware.use ApiSteward::Signal  if options.signal
      end

      initializer "api_steward.notifications" do |app|
        next unless app.config.api_steward.notifications

        ApiSteward.instrument.subscribe do |event, payload|
          ActiveSupport::Notifications.instrument(event, payload)
        end
      end
    end
  end
end
