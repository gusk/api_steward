# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Observe** (Stage 0): read-only Rack middleware that records version and client usage
  through a small, dependency-free instrumentation hub. Fails open — it never breaks a
  request, and costs nothing when no one is subscribed.
- **Signal** (Stage 1): `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) response
  headers, plus an optional deprecation `Link`, driven by a declared version lifecycle.
- **Govern** (Stage 2): enforce retired versions (`410`), internal-only access (`403`,
  trusted callers only), and scheduled brownouts (`503`), each as an RFC 9457
  `application/problem+json` response. Fails open on internal error.
- **Identity**: a pluggable strategy chain (`:from_env`, `:from_api_key`, `:from_ip`,
  `:anonymous`, or any callable), tried in order, with a trust bit — only a verified
  identity is trusted, so an unverified claim can't slip past an internal-only gate.
- **Dashboard**: a mountable Rack app showing live version usage (HTML-escaped).
- Works in any Rack host (Rails, Sinatra, Hanami, Roda, Grape, plain Rack); core depends
  only on `rack`.
- Version names are matched case-insensitively across the registry and resolution.

[Unreleased]: https://github.com/gusk/api_steward/commits/main
