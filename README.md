# api_steward

A place inside your app to see, signal, and govern the lifecycle of your API versions.

`api_steward` is Rack middleware (plus a small mountable dashboard) that watches the
requests your API already serves. It tells you which versions are being used and by
whom, lets you signal deprecation with the right HTTP headers, and — when you're ready
— lets you control who can reach each version and retire old ones on your terms. It
does this without changing your routes or controllers, and it works in any Rack app:
Rails, Sinatra, Hanami, Roda, Grape, or plain Rack.

> **Status:** early development. The design is written down in [DESIGN.md](DESIGN.md);
> the code is being built from it. Interfaces shown below are the intended Stage 0
> experience and may still shift. Feedback is welcome.

## The problem

Deciding when to deprecate or remove an API version is usually done half-blind. You
can see traffic in your logs somewhere, but the question that actually matters —
*which versions are still in use, and who would I break if I turned this one off?* —
is hard to answer, and it lives nowhere near the controls for changing a version's
status. So old versions linger, and removing one feels risky.

`api_steward` puts the visibility and the controls in the same place.

## How it works: observe, then signal, then govern

You can adopt it one step at a time. The first step is read-only and safe to add to
production — it never blocks a request.

### 1. Observe

Add the middleware and mount the dashboard:

```ruby
# Gemfile
gem "api_steward"
```

```ruby
# config.ru — or wherever you assemble your Rack stack
require "api_steward"

ApiSteward.configure do |c|
  c.version_from :path   # detect the version in the URL, e.g. /api/v1/...
                         # (:header and :param are also available)
end

use ApiSteward::Observe

map "/api_steward" do
  run ApiSteward::Dashboard
end
```

That's it. Open `/api_steward` and you'll see which versions are being called, and how
often. This stage uses best-effort client identification, which is all that usage
attribution needs.

### 2. Signal

Declare a version's lifecycle and add the `Signal` middleware. api_steward then sets
the standard `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) response headers for
you, so clients are told in a way their tools can read. Nothing is blocked.

```ruby
ApiSteward.configure do |c|
  c.version_from :path
  c.version "v1", status: :deprecated, sunset: "2026-11-11"
  c.version "v2"
end

use ApiSteward::Signal
```

### 3. Govern

When you're ready to enforce, you can restrict a version to internal callers, schedule
a brownout, or return a clean `410 Gone` once it's retired — with proper
`application/problem+json` error bodies. This stage relies on trusted client identity;
see [DESIGN.md](DESIGN.md) for how that works and why it's kept separate from
observation.

## Using it with Rails

The core is plain Rack, so it already works in Rails. An optional `api_steward-rails`
gem adds the usual conveniences (inserting the middleware and mounting the dashboard
for you). You never need it, but it's there if you want it.

## Design

The full design — the adoption model, the resolver, the identity-and-trust approach,
the standards it follows, and what's intentionally left out — is in
[DESIGN.md](DESIGN.md).

## License

MIT (planned).
