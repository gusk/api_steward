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
- `ApiSteward::Rails::Identify` controller concern — `api_steward_identify { ... }` sets
  the api_steward client from your authenticated user.
- `ApiSteward::Rails::Govern` controller concern — an `api_steward_govern!` before_action
  that enforces a version's lifecycle using the controller-resolved client, rendering
  RFC 9457 `application/problem+json` when a request is turned away.

[Unreleased]: https://github.com/gusk/api_steward/commits/main
