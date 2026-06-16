# api_steward-rails

Rails integration for [api_steward](https://github.com/gusk/api_steward).

The core gem is plain Rack and works in Rails already. This shim makes the setup
effortless: it wires the middleware for you, gives you an installer, and can forward
events to `ActiveSupport::Notifications`.

> **Status:** early development, tracking the core gem.

## Install

```ruby
# Gemfile
gem "api_steward-rails"
```

```sh
bin/rails g api_steward:install
```

That writes `config/initializers/api_steward.rb` for you to fill in.

## What the Railtie does

By default it inserts the read-only `Observe` middleware — safe, and it starts
answering "who's on v1?". Turn on the rest when you're ready, in `config/application.rb`:

```ruby
config.api_steward.observe = true        # default
config.api_steward.signal  = true        # send Deprecation / Sunset headers
config.api_steward.govern  = true        # enforce gone / internal / brownout
config.api_steward.notifications = true  # re-emit events on ActiveSupport::Notifications
```

With `notifications` on, you can subscribe with tooling you already have:

```ruby
ActiveSupport::Notifications.subscribe("api_steward.request") do |_name, _start, _finish, _id, payload|
  # payload => { version:, client_id:, tier:, status:, method:, path:, duration: }
end
```

## The dashboard

Mount it wherever your admin routes live (behind your own auth):

```ruby
mount ApiSteward::Dashboard => "/api_steward"
```

## License

[MIT](../LICENSE).
