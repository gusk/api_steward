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

## Bridging your app's identity

In Rails, who's calling (`current_user`, the tenant) is known inside the controller,
after authentication — too late for the middleware. Bring it into api_steward with a
concern:

```ruby
class ApplicationController < ActionController::API
  include ApiSteward::Rails::Identify

  api_steward_identify do
    next unless current_user
    ApiSteward::Client.new(id: current_user.id,
                           tier: current_user.staff? ? :internal : :external,
                           trusted: true)
  end
end
```

The block runs as a `before_action` and sets the client, so `Observe` and `Signal`
attribute correctly and the `:from_env` strategy can see it. Returning `nil` leaves the
caller anonymous.

## Enforcing in a controller

Middleware `Govern` runs before authentication, so it can't gate on `current_user`. When
a gate depends on who's signed in, enforce in the controller instead:

```ruby
class InternalController < ApplicationController
  include ApiSteward::Rails::Govern
  before_action :api_steward_govern!
end
```

It resolves the version and the now-authenticated client, and renders an RFC 9457
problem document if the version's lifecycle says the request shouldn't proceed.

## The dashboard

Mount it wherever your admin routes live (behind your own auth):

```ruby
mount ApiSteward::Dashboard => "/api_steward"
```

## License

[MIT](../LICENSE).
