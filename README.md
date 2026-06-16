# api_steward

A place inside your app to see, signal, and govern the lifecycle of your API versions.

`api_steward` is Rack middleware (plus a small mountable dashboard) that watches the
requests your API already serves. It tells you which versions are being used and by
whom, lets you signal deprecation with the right HTTP headers, and — when you're ready —
lets you control who can reach each version and retire old ones on your terms. It does
this without changing your routes or controllers, and it works in any Rack app: Rails,
Sinatra, Hanami, Roda, Grape, or plain Rack.

> **Status:** early development. The three layers — observe, signal, govern — work and
> are tested, but the API may still shift before 1.0. The full design is in
> [DESIGN.md](DESIGN.md). Feedback is welcome.

## The problem

Deciding when to deprecate or remove an API version is usually done half-blind. You can
see traffic in your logs somewhere, but the question that actually matters — *which
versions are still in use, and who would I break if I turned this one off?* — is hard to
answer, and it lives nowhere near the controls for changing a version's status. So old
versions linger, and removing one feels risky.

`api_steward` puts the visibility and the controls in the same place.

## Installation

Needs Ruby 3.2+. The core gem depends only on `rack`, so it runs in any Rack app.

```ruby
# Gemfile
gem "api_steward"
```

On Rails, add the companion shim too — it wires the middleware up for you and gives you
an installer (see [Using it with Rails](#using-it-with-rails)):

```ruby
gem "api_steward-rails"
```

Then `bundle install`.

## How it works: observe, then signal, then govern

You can adopt it one step at a time. The first step is read-only and safe to add to
production — it never blocks a request.

### 1. Observe

Add the middleware and mount the dashboard:

```ruby
# config.ru — or wherever you assemble your Rack stack
require "api_steward"

ApiSteward.configure do |c|
  c.version_from :path   # detect the version in the URL, e.g. /api/v1/...
                         # (:header and :param are also available)
end

ApiSteward.usage  # start the dashboard's tally now, so it counts from the first request

use ApiSteward::Observe

map "/api_steward" do
  run ApiSteward::Dashboard
end
```

Open `/api_steward` and you'll see which versions are being called, and how often. This
stage uses best-effort client identification, which is all that usage attribution needs.

### 2. Signal

Declare a version's lifecycle and add the `Signal` middleware. api_steward then sets the
standard `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) response headers for you, so
clients are told in a way their tools can read. Nothing is blocked.

```ruby
ApiSteward.configure do |c|
  c.version_from :path
  c.version "v1", status: :deprecated, sunset: "2026-11-11"
  c.version "v2"
end

use ApiSteward::Signal
```

### 3. Govern

When you're ready to enforce, add the `Govern` middleware. It can return a clean
`410 Gone` once a version is retired, restrict a version to internal callers, or run a
scheduled brownout — each as a proper `application/problem+json` (RFC 9457) response.

```ruby
ApiSteward.configure do |c|
  c.version_from :path
  c.version "v0", status: :gone        # 410 Gone
  c.version "v2", access: :internal    # 403 for external callers
  c.version "v3", brownouts: Time.utc(2026, 7, 1, 9)..Time.utc(2026, 7, 1, 9, 15) # 503 during the window
end

use ApiSteward::Govern
```

Restricting a version to internal callers needs a *trusted* client identity — an
unverified "I'm internal" claim is refused. See [DESIGN.md](DESIGN.md) for how identity
and trust work, and why that's kept separate from observation.

The three middlewares are independent; a common full stack, in order, is:

```ruby
use ApiSteward::Observe  # outermost, so it records blocked requests too
use ApiSteward::Govern
use ApiSteward::Signal
```

## Identifying clients

Both "who's on v1" and "internal only" need to know who is calling. Configure how to
identify a client; the strategies are tried in order, and the first match wins.

```ruby
ApiSteward.configure do |c|
  c.identify do
    strategy :from_env, key: "api_steward.client"    # your app set a Client after auth
    strategy :from_api_key, header: "X-Api-Key" do |key|
      account = Account.find_by(api_key: key) or next nil
      ApiSteward::Client.new(id: account.id, tier: account.tier, trusted: true)
    end
    strategy :from_ip, internal: ["10.0.0.0/8"]       # calls from the VPC are internal
    strategy :anonymous
  end
end
```

Only a verified identity is `trusted`, and only a trusted internal client may reach an
`access: :internal` version. A bare API-key header (no lookup) counts for attribution
but stays untrusted, so it can't be used to slip past a gate.

## The dashboard

A small, read-only web view of who's using which version. It's a plain Rack app, so it
mounts in any host:

```ruby
# Rack (config.ru)
map "/api_steward" do
  run ApiSteward::Dashboard
end

# Rails (config/routes.rb)
mount ApiSteward::Dashboard => "/api_steward"
```

Per version it shows total requests, the number of distinct identified clients, and when
the version was last seen. A few things worth knowing:

- **Mount it behind your own admin authentication.** It exposes usage data, and
  api_steward does not add auth of its own.
- It only displays what `Observe` has collected, and the tally begins when
  `ApiSteward.usage` is first referenced. Touch it at boot so nothing is missed (the
  Rails installer does this for you):

  ```ruby
  ApiSteward.usage
  ```

## Using it with Rails

The core is plain Rack, so it already works in Rails. The optional `api_steward-rails`
gem adds the conveniences:

```sh
bin/rails g api_steward:install
```

That writes `config/initializers/api_steward.rb`, and a Railtie inserts the middleware
you enable in `config/application.rb`:

```ruby
config.api_steward.observe = true        # default — record version usage
config.api_steward.signal  = true        # send Deprecation / Sunset headers
config.api_steward.govern  = true        # enforce gone / internal / brownout
config.api_steward.notifications = true  # re-emit events on ActiveSupport::Notifications
```

See [api_steward-rails](api_steward-rails/README.md) for the details.

## Troubleshooting

**The dashboard is empty.** The usage tally only records once it's subscribed. Make sure
`ApiSteward.usage` is referenced at boot, and that `ApiSteward::Observe` is in your
middleware stack.

**The "Clients" column is always 0.** Every caller is anonymous until you configure
identity — see [Identifying clients](#identifying-clients).

**A version isn't being detected.** With `version_from :path`, only `vN` path segments
are recognized (`/api/v1/...`); a name like `/api/admin/...` won't match. Check that your
declared version names line up with what's actually in the request, and that
`version_from` matches your scheme (`:path`, `:header`, or `:param`).

**No `Deprecation` / `Sunset` headers.** Declare the version with a `deprecation:` or
`sunset:` date, and add `ApiSteward::Signal` to the stack.

**An `access: :internal` version lets everyone in (200).** Usually one of two things: the
version name doesn't match the detected version (see above), or the caller isn't a
*trusted* internal client. Middleware-level `Govern` runs before your app authenticates,
so establish identity with a middleware-level strategy (`:from_api_key`, `:from_ip`)
rather than something only known inside a controller.

**A blocked request (410/403/503) didn't appear on the dashboard.** Put `Observe`
outermost (before `Govern`) so it records blocked requests too.

## Design

The full design — the adoption model, the resolver, the identity-and-trust approach, the
standards it follows, and what's intentionally left out — is in [DESIGN.md](DESIGN.md).

## License

[MIT](LICENSE).
