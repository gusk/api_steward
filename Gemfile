# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "minitest", "~> 5.0"
  gem "rake", "~> 13.0"
end

group :development do
  gem "rackup"  # Rack 3 split the `rackup` command into its own gem
  gem "webrick" # a simple server for the config.ru example
end
