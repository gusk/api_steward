# Changelog

All notable changes to api_steward-rails are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- A Railtie that inserts the api_steward middleware you enable — `Observe` by default,
  `Signal` and `Govern` via `config.api_steward.*` flags — in the correct order.
- `rails g api_steward:install`, which writes `config/initializers/api_steward.rb`.
- An opt-in bridge from api_steward events to `ActiveSupport::Notifications`
  (`config.api_steward.notifications = true`).

[Unreleased]: https://github.com/gusk/api_steward/commits/main
