# frozen_string_literal: true

require "ipaddr"

module ApiSteward
  # Built-in identity strategies. Each responds to #call(request) and returns a Client
  # or nil. Identity tries them in order; the first non-nil wins.
  #
  # A note on trust — this is the part that prevents bad surprises: a strategy may mark
  # a client `trusted: true` only when identity was established by something we can
  # actually rely on (the app vouching for it, a verified key lookup, or the network).
  # A bare, unverified header is attribution only (trusted: false), so it can never be
  # used to slip past an internal-only gate.
  module Strategies
    module_function

    def build(spec, **options, &block)
      case spec
      when :from_env     then FromEnv.new(options.fetch(:key, CLIENT_ENV_KEY))
      when :from_api_key then FromApiKey.new(options.fetch(:header), &block)
      when :from_ip      then FromIp.new(options.fetch(:internal, []))
      when :anonymous    then Anonymous
      when Symbol        then raise ArgumentError, "unknown identity strategy #{spec.inspect}"
      else
        unless spec.respond_to?(:call)
          raise ArgumentError, "a strategy needs a built-in name or a callable"
        end
        spec
      end
    end

    # The app, having authenticated, left a Client in the Rack env. Trusted, because
    # the app vouched for it.
    class FromEnv
      def initialize(key)
        @key = key
      end

      def call(request)
        request.get_header(@key)
      end
    end

    # Read an API key from a header. With a lookup block, the block maps the key to a
    # Client and decides trust. Without one, we can't verify the key, so it's
    # attribution only — trusted: false.
    class FromApiKey
      def initialize(header, &lookup)
        @header = "HTTP_#{header.upcase.tr("-", "_")}"
        @lookup = lookup
      end

      def call(request)
        key = request.get_header(@header)
        return nil if key.nil? || key.empty?
        return @lookup.call(key) if @lookup

        Client.new(id: key, tier: :external, trusted: false)
      end
    end

    # Tier by network: a caller from one of the declared internal ranges is a trusted
    # internal client. Anyone else falls through to the next strategy.
    class FromIp
      def initialize(internal)
        @ranges = Array(internal).map { |cidr| IPAddr.new(cidr) }
      end

      def call(request)
        ip = request.ip
        return nil if ip.nil?

        addr = parse(ip) or return nil
        return nil unless @ranges.any? { |range| range.include?(addr) }

        Client.new(id: ip, tier: :internal, trusted: true, meta: { source: :ip })
      end

      private

      def parse(ip)
        IPAddr.new(ip)
      rescue IPAddr::InvalidAddressError
        nil
      end
    end

    # The graceful floor: a known-anonymous caller.
    module Anonymous
      module_function

      def call(_request)
        Client.anonymous
      end
    end
  end
end
