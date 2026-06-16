# frozen_string_literal: true

require "rails/generators/base"

module ApiSteward
  module Generators
    # Writes config/initializers/api_steward.rb. Run with:
    #
    #   rails g api_steward:install
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "api_steward.rb", "config/initializers/api_steward.rb"
      end

      def show_post_install
        say ""
        say "api_steward is installed.", :green
        say "Next steps:"
        say "  - Review config/initializers/api_steward.rb and declare your versions."
        say "  - Mount the dashboard in config/routes.rb (behind your admin auth):"
        say %(      mount ApiSteward::Dashboard => "/api_steward")
        say "  - Turn on enforcement when ready: config.api_steward.govern = true"
      end
    end
  end
end
