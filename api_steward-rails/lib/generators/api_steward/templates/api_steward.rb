# frozen_string_literal: true

# api_steward configuration. See https://github.com/gusk/api_steward
#
# Middleware is wired up by the Railtie. Enable more in config/application.rb:
#   config.api_steward.signal = true   # send deprecation/sunset headers
#   config.api_steward.govern = true   # enforce gone / internal / brownout
ApiSteward.configure do |c|
  # Where the API version lives in a request.
  c.version_from :path # or :header, name: "X-Api-Version" / :param, name: "version"

  # Declare your versions and their lifecycle.
  # c.version "v1", status: :deprecated, sunset: "2026-11-11"
  # c.version "v2"

  # Who is calling? Strategies are tried in order; the first match wins.
  c.identify do
    strategy :from_env, key: "api_steward.client" # set this in a controller after auth
    # strategy :from_api_key, header: "X-Api-Key" do |key|
    #   account = Account.find_by(api_key: key) or next nil
    #   ApiSteward::Client.new(id: account.id, tier: account.tier, trusted: true)
    # end
    # strategy :from_ip, internal: ["10.0.0.0/8"]
    strategy :anonymous
  end
end

# Start the dashboard's usage tally now, so it sees traffic from the first request.
ApiSteward.usage
