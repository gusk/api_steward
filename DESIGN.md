# api_steward — Design Document

> An API lifecycle **control plane** for **Rack-based Ruby apps** (Rails, Sinatra,
> Hanami, Roda, Grape, plain Rack). See who is calling every version of your API,
> govern each version's lifecycle from a dashboard, and emit standards-correct
> deprecation signals — **without changing a single route.**
>
> Rack-native by design: the core depends only on `rack`. Rails is just one of the
> hosts it runs in — popular frameworks get a thin, optional shim (§10), never a hard
> dependency.

- **Status:** Draft
- **Last updated:** 2026-06-16
- **Scope of this document:** what api_steward is, the core architecture, and the
  MVP boundary. Implementation specifics (class names, table schemas) are left for
  later, once the design settles.

---

## 1. The problem

API versioning is a recurring headache, and the pain falls on three different people
who today have **no shared source of truth**:

- **The engineer** asks: *"Which version actually served this request, and is it
  safe to delete the v1 controller?"*
- **The product manager** asks: *"Who is still on v1, and can I deprecate it without
  breaking a paying customer?"*
- **The CTO / staff engineer** asks: *"What is our deprecation liability — how many
  external clients are pinned to endpoints we want to retire?"*

These are the same question viewed from three altitudes: **what is the lifecycle
state of each API version, who depends on it, and how do we move it forward safely.**

Today, answering it in a Ruby app means stitching together a few things: hand-rolled
middleware for deprecation headers, logs you have to dig through, a spreadsheet of
"who's on what," and a deploy every time you want to flip a version from active to
deprecated. The decision to retire a version gets made *blind*, because usage data
lives somewhere other than the controls.

## 2. What api_steward is

api_steward gives you one place in your app to manage an API version across its whole
life:

- **Observe** — see which versions are being used, and by whom.
- **Signal** — tell clients when a version is deprecated, and when it will sunset.
- **Govern** — decide who can reach each version, and retire it on your own terms.

It does all of this without touching your routes or controllers. It watches the
requests you already serve and responds to them according to rules you can change from
a dashboard at any time, with no deploy required.

That's the whole of it. It does one thing: it helps you manage the lifecycle of your
API versions.

## 3. Core concept: control plane vs. data plane

Two layers, kept apart on purpose, because they serve different people:

- **Data plane** — the actual request flow. *You already own this:* your routes,
  controllers, auth, and whatever versioning scheme you adopted years ago (path,
  header, param, subdomain). `api_steward` does **not** replace it.
- **Control plane** — where people *see and decide* what happens to versions. This is
  the layer api_steward provides, and it is the heart of the project.

`api_steward` is a Ruby/Rack-native control plane: it **observes** the data plane it
does not own, and **acts** on it (headers, blocks, brownouts) according to lifecycle
rules that a human can change from a dashboard without a deploy. Because it is a Rack
middleware + Rack dashboard, it mounts in any Rack host — Rails, Sinatra, Hanami,
Roda, Grape, or bare Rack.

```
                         [ Incoming request ]
                                  |
                                  v
   +--------------------------------------------------------------+
   |  Resolver  --  (version, client_id, tier)                    |  <-- integration seam
   +--------------------------------------------------------------+
                                  |
                                  v
   +--------------------------------------------------------------+
   |  Governance middleware                                       |
   |   - look up version lifecycle state (cached)                 |
   |   - enforce status (active / deprecated / gone / brownout)   |
   |   - enforce tier (internal vs. external)                     |
   |   - inject Sunset / Deprecation headers (RFC 8594 / 9745)    |
   |   - on block: application/problem+json (RFC 9457)            |
   |   - emit telemetry event                                     |
   +--------------------------------------------------------------+
                       |                          |
        (pass through) v                          v (emit, fire-and-forget)
          [ your existing app ]            [ telemetry sink -> dashboard ]
```

## 4. The Resolver

Integration is the priority: the gem has to drop into an app whose versioning it
didn't design. So everything rests on one piece — the Resolver. Given an incoming
request, it answers:

1. **Which version is this?** (path segment, `Accept` header, custom header, param,
   subdomain)
2. **Who is the client, and what tier?** (API key, JWT claim, mTLS, IP allowlist —
   or "anonymous")
3. **What resource is being touched?**

Everything downstream (headers, blocking, brownouts, telemetry, dashboard) is
plumbing hanging off this `(version, client_id, tier)` tuple.

It works through a small adapter design: we ship resolvers for the common conventions,
and leave a clean interface for "my versioning is a little unusual — here's a lambda."
Detecting the version is mechanical; **identifying the client is the harder part**, and
where real integrations tend to get messy.

Crucially, identity has **two trust levels tied to the adoption stage** (§5):
best-effort/untrusted is enough for Stage 0 observation, while Stage 2 enforcement
requires *trusted* identity. The full identity/trust design is in §8.

## 5. Adoption model: observe → signal → govern

The product is built as a **progressive funnel**, not a monolith. The adoption layer
— the thing that first gets `api_steward` into a real codebase — is the **read-only
"observe" tier**, because it clears the three things that gate adoption: near-zero
config, zero risk (it never blocks a request), and it answers the motivating question
("who's on v1?") on day one. Governance is the next step, taken once a team is invested
and has data showing they need it.

Complexity is disclosed progressively. Each stage is independently shippable and
independently valuable.

| Stage | What it does | Config required | Risk | Identity needs |
|---|---|---|---|---|
| **0. Observe** (the wedge) | Live dashboard of version × client usage | ~2 lines | none — read-only, **fail-open** | **best-effort, untrusted** |
| **1. Signal** | Emit `Sunset` / `Deprecation` headers | declare versions | low — response headers only | none |
| **2. Govern** | Enforce tiers, brownouts, `410 Gone` | strategy chain + trust (§8) | high — blocks traffic | **trusted** (now it matters) |

The MVP is **Stage 0**. Stages 1 and 2 follow once the wedge is adopted.

### Components, mapped to stages

1. **Resolver** *(Stage 0)* — pluggable `(version, client_id, tier)` extraction. The
   integration seam; works alongside existing routes. At Stage 0 identity is
   best-effort and **untrusted** — fine, because we are only attributing telemetry.
2. **Telemetry** *(Stage 0)* — emit structured events (`version`, `client_id`,
   `tier`, `status`, `path`, `ts`). **Emit, don't store:** publish through a tiny
   **built-in instrumentation interface (zero deps)** so users can route events
   anywhere; ship an *optional* `ActiveSupport::Notifications` bridge for apps that
   already have it. Storage is a **pluggable adapter** (in-memory default; optional
   Redis / Sequel / ActiveRecord adapters) — never an ActiveRecord requirement.
3. **Dashboard** *(Stage 0)* — a **mountable Rack app**; because it is plain Rack, it
   is welcome in any Rack host. Server-rendered ERB + vanilla JS, with **SSE** for
   live updates (no framework JS
   dependency): version × client usage view ("who's on v1"). Status toggles and the
   brownout scheduler appear here once Stage 2 lands.
4. **Header injection** *(Stage 1)* — `Sunset` (RFC 8594) and `Deprecation`
   (RFC 9745) headers for versions declared deprecated. Non-blocking.
5. **Governance middleware** *(Stage 2)* — enforces status + tier; returns
   `application/problem+json` (RFC 9457) on block; brownouts. Reads lifecycle state
   from an **in-process cache** (short TTL / pub-sub invalidation) — never a DB read
   on the hot path. **Requires trusted identity (§8).**
6. **Config-as-code + dynamic override** *(Stage 1–2)* — versions declared in a
   config file as the source of truth, with dashboard toggles persisted as overrides.

## 6. Standards (worth getting right)

- **`Sunset` header — RFC 8594.** `Sunset: Wed, 11 Nov 2026 00:00:00 GMT`.
- **`Deprecation` header — RFC 9745.** Note the correct syntax is a timestamp
  (`Deprecation: @1736899200`), **not** `Deprecation: true` (that is the old draft).
- **Problem Details — RFC 9457** (obsoletes 7807). `application/problem+json` bodies
  for every block, e.g.:
  ```json
  {
    "type": "https://example.com/problems/version-retired",
    "title": "API Version Retired",
    "status": 410,
    "detail": "Version 1 was retired on 2026-06-01. Migrate to Version 2.",
    "instance": "/api/v1/users"
  }
  ```

## 7. Design principles

0. **Rack-native, framework-friendly.** The core depends only on `rack` — no Rails,
   no ActiveSupport, no ActiveRecord. Everything framework-specific (a notifications
   bridge, storage, Railtie sugar) lives in an optional adapter or shim (§10). Being
   Rack-native doesn't mean ignoring Rails — every popular host, Rails included, gets
   a first-class shim.
1. **Router-agnostic.** We never ask you to adopt our routing. api_steward fits in
   alongside whatever versioning you already use — path, header, param, subdomain, or
   hand-rolled namespaces — so it can help as many people as possible.
2. **Cheap reads.** No per-request DB hit. Lifecycle state is cached in-process.
3. **Emit, don't store.** Telemetry is instrumentation; storage is opt-in.
4. **Config-as-code, overridable live.** Versions are reviewable in git; status is
   flippable without a deploy.
5. **Safe by default.** Blocking a request returns a correct, machine-readable error
   — never an HTML 500.
6. **Fail-open at the observe layer.** Stage 0 must *never* break a request: any
   hiccup in resolution or telemetry is swallowed and the request passes straight
   through. That's the price of being safe to drop into a codebase, and it's a hard
   rule.
7. **Progressive disclosure of complexity.** Day-one install requires ~2 lines and no
   identity/trust decisions. The strategy chain and trust machinery (§8) are opt-in,
   surfaced only when a team graduates to Stage 2 enforcement.

## 8. Identity & trust (Stage 2 design)

Identity resolution is the hardest part of the integration seam, but — per §5 — it is
a **Stage 2 (govern) concern, not a Stage 0 (observe) one.** Stage 0 attributes
telemetry with best-effort, *untrusted* identity; only enforcement requires *trusted*
identity. This section specifies the Stage 2 design so the public API is stable, even
though the code lands later.

### The core insight

`api_steward` runs early, before the app authenticates a request. Extracting an
identifier from an unverified token is fine for *attribution* (worst case: bad
analytics) but is a **security hole** if used to enforce an "internal-only" gate — an
attacker forges the claim. Therefore:

> **Separate "identify for attribution" (best-effort, untrusted OK) from "authorize
> for enforcement" (must be trusted).** Enforcement that is a security boundary
> requires `trusted: true`; otherwise `api_steward` fails safe.

### The value object

```ruby
ApiSteward::Client.new(
  id:      "acme-corp",  # stable identifier for attribution; nil = anonymous
  tier:    :external,    # arbitrary label access rules key off of (not a fixed enum)
  trusted: true,         # was identity established by a trustworthy means?
  meta:    { name: "Acme Corp" }  # optional, for dashboard display
)
```

Telemetry uses `id`/`tier` regardless of `trusted`. Enforcement requires
`trusted: true` or it fails safe.

### The strategy chain (tried in order, first answer wins)

```ruby
ApiSteward.configure do |c|
  c.identify do
    strategy :from_env, key: "api_steward.client"          # blessed path: app vouches
    strategy :from_api_key, header: "X-Api-Key" do |key|   # server-controlled -> trusted
      rec = ApiKey.find_by(token: key) or next nil
      Client.new(id: rec.client_id, tier: rec.tier, trusted: true)
    end
    strategy :from_ip, internal: ["10.0.0.0/8"]            # network tiering
    strategy ->(req) { ... }                               # escape hatch
    strategy :anonymous                                    # graceful floor
  end
end
```

The **blessed path is `:from_env`**: the app, having already authenticated, hands us
the principal by setting `request.env["api_steward.client"]` from any post-auth hook
— a Rails `before_action`, a Sinatra `before` filter, or any downstream Rack
middleware. This sidesteps the security footgun entirely and assumes nothing about
the app's framework or auth stack. Built-ins: `:from_env`, `:from_api_key`, `:from_jwt`
(`verify:` option; no verifier ⇒ `trusted: false`), `:from_ip`, `:anonymous`, + raw
lambda.

### Decisions (recommended defaults — provisional)

- **Untrusted identity hitting an internal-only version:** **block** (`403`), with a
  config override for lenient/allow-but-flag. Safe-by-default.
- **Placement:** default **(A)** middleware inserted *after* the app's auth
  middleware; document **(B)** a hybrid `before_action` concern as the fallback for
  apps where identity only resolves in the controller.
- **`:from_jwt` in MVP:** **defer.** JWT-with-verification (algorithms, key rotation)
  is easy to ship subtly wrong; ship `:from_env` + `:from_api_key` + `:from_ip` +
  lambda first.

### Remaining open questions

- **Cache invalidation transport.** TTL vs. pub-sub (Redis) vs. cache-version key.
- **Brownout semantics.** Block all traffic, or only external tiers? Per-client
  exemptions?
- **Multi-process state.** Where does the lifecycle registry live so that a dashboard
  toggle in one process is seen by all workers (Redis vs. DB + cache-bust)?

## 9. Out of scope for v1

To keep the project focused and easy to maintain, a few things are intentionally left
aside for now:

- A routing engine / version-dispatch DSL.
- Code generators / controller scaffolding.
- OpenAPI/Swagger splitting and SDK generation.
- Cross-version "fallback" routing — we'd rather not quietly reroute through
  controllers we don't own, since that hides which version actually served a request.

Any of these could return later as an opt-in add-on, once the control plane has proven
itself.

## 10. Packaging & dependency strategy

A layered approach: a small core that asks for very little, plus thin optional shims
for the frameworks and backends people use.

| Gem | Depends on | Provides |
|---|---|---|
| **`api_steward`** (core) | `rack` only | Resolver, observe/govern middleware, instrumentation interface, storage adapter interface, mountable Rack dashboard (ERB + SSE) |
| `api_steward-redis` (optional) | `redis` | Redis storage + telemetry adapter |
| `api_steward-activerecord` (optional) | `activerecord` | SQL storage adapter, migrations |
| ActiveSupport notifications bridge (optional, in-core behind a require) | `activesupport` | Re-emit events on `ActiveSupport::Notifications` |
| **`api_steward-rails`** (optional) | `railties` | Railtie auto-insert middleware, mount sugar, generators |

The idea: a Sinatra or bare-Rack user installs **only** `api_steward` and brings in
nothing they didn't ask for, while a Rails user can add `api_steward-rails` for
first-class ergonomics. Every host works the same way, and none carries weight it
doesn't need.

## 11. Engineering tenets (how we build)

We build in the spirit Matsumoto built Ruby: for the **happiness of the person using
it.** api_steward should feel natural to set up, behave with the least possible
surprise, and ask for nothing it doesn't need. This also keeps it easy to adopt
anywhere — the smaller a library's footprint, the more easily any host can take it on.

This isn't object-design dogma. We use small, clear objects and tidy seams where they
make the code easier to understand, and we're equally willing to offer an expressive,
readable DSL or a bit of convenience where it makes the gem pleasant to use — as long
as nothing surprising happens out of sight.

- **Expressive, least-surprise API.** Configuration should read like intent
  (`ApiSteward.configure do … end`), and behavior should be predictable. A readable
  DSL is fine; action-at-a-distance is not.
- **Configurable globally or explicitly.** The global setup is the easy default; an
  explicit, instantiable config object is always there when you want it — for testing,
  thread-safety, or running more than one instance.
- **A guest, not a host.** You `use` our middleware and create our objects; we never
  take over your app or insist on a boot hook in the core. Hosts wrap us; we don't
  presume on the host.
- **Earn every dependency.** The core needs only `rack`. Everything else is an opt-in
  adapter or shim (§10).
- **Duck-typed adapters, no base class to inherit.** A storage adapter is simply any
  object that responds to `#read`/`#write`; a strategy responds to `#call(request)`.
- **No monkey-patching.** We don't reopen `Rack::Request`, core classes, or other
  gems — we wrap instead.
- **Immutable value objects via `Data.define`** (Ruby 3.2+) — `Client`, `Version`, and
  decision objects: expressive, frozen, and comparable.
- **An instrumentation contract shaped like `ActiveSupport::Notifications`, yet
  depending on neither** — so the bridge is a one-liner for apps that already have it,
  and entirely free for everyone else.
- **A read-mostly, frozen registry, swapped atomically** — safe under threads and
  fibers, with no locks on the hot path.

One thing to keep in mind: **small isn't austere, and independent isn't cold.** Few
dependencies should not mean an awkward API, and standing on our own should not mean a
poorer experience on any particular framework. The optional shims (§10) should feel
native on their host.
