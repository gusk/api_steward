# frozen_string_literal: true

require_relative "lib/api_steward/rails/version"

Gem::Specification.new do |spec|
  spec.name    = "api_steward-rails"
  spec.version = ApiSteward::Rails::VERSION
  spec.authors = ["TODO: your name"]
  spec.email   = ["gusssk@gmail.com"]

  spec.summary     = "Rails integration for api_steward."
  spec.description = "Drop api_steward into a Rails app: a Railtie inserts the " \
                     "middleware you enable, an installer writes the initializer, and " \
                     "events can flow to ActiveSupport::Notifications."
  spec.homepage = "https://github.com/gusk/api_steward"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "api_steward"
  spec.add_dependency "railties", ">= 7.0"
end
