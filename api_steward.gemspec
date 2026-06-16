# frozen_string_literal: true

require_relative "lib/api_steward/version"

Gem::Specification.new do |spec|
  spec.name    = "api_steward"
  spec.version = ApiSteward::VERSION
  spec.authors = ["August King"]
  spec.email   = ["gusssk@gmail.com"]

  spec.summary     = "See, signal, and govern the lifecycle of your API versions."
  spec.description = "Rack middleware and a small mountable dashboard to observe API " \
                     "version usage, signal deprecation with standard HTTP headers, " \
                     "and govern access to each version — without changing your " \
                     "routes. Works in any Rack app."
  spec.homepage = "https://github.com/gusk/api_steward"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = spec.homepage
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "README.md", "DESIGN.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.2"
end
