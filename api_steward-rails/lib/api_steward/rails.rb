# frozen_string_literal: true

require "api_steward"
require "api_steward/rails/version"
require "api_steward/rails/railtie"
require "api_steward/rails/identify"
require "api_steward/rails/govern"

module ApiSteward
  # Rails glue for api_steward. Bundler requires this automatically for the
  # api_steward-rails gem, which loads the Railtie: it wires the middleware you've
  # enabled into the app, and can bridge events to ActiveSupport::Notifications.
  #
  # The core gem stays plain Rack; everything Rails-specific lives here.
  module Rails
  end
end
