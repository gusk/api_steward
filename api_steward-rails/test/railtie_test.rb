# frozen_string_literal: true

require "test_helper"

# Exercises the Railtie's middleware initializer against a small app double, so we test
# our wiring without booting a whole Rails app.
class RailtieTest < Minitest::Test
  # Records what middleware.use was asked to insert.
  class MiddlewareRecorder
    attr_reader :used

    def initialize
      @used = []
    end

    def use(klass, *)
      @used << klass
    end
  end

  def middleware_for(observe:, govern:, signal:)
    options = ActiveSupport::OrderedOptions.new
    options.observe = observe
    options.govern  = govern
    options.signal  = signal

    config = Object.new
    config.define_singleton_method(:api_steward) { options }

    recorder = MiddlewareRecorder.new
    app = Object.new
    app.define_singleton_method(:config) { config }
    app.define_singleton_method(:middleware) { recorder }

    initializer = ApiSteward::Rails::Railtie.instance.initializers
                                            .find { |i| i.name == "api_steward.middleware" }
    initializer.run(app)
    recorder.used
  end

  def test_observe_only_by_default
    assert_equal [ApiSteward::Observe], middleware_for(observe: true, govern: false, signal: false)
  end

  def test_enables_govern_and_signal_in_order
    used = middleware_for(observe: true, govern: true, signal: true)
    assert_equal [ApiSteward::Observe, ApiSteward::Govern, ApiSteward::Signal], used
  end

  def test_observe_can_be_turned_off
    assert_equal [ApiSteward::Govern], middleware_for(observe: false, govern: true, signal: false)
  end

  def test_default_config_enables_observe_only
    config = ApiSteward::Rails::Railtie.config.api_steward
    assert config.observe
    refute config.govern
    refute config.signal
    refute config.notifications
  end
end
