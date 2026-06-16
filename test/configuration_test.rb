# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @config = ApiSteward::Configuration.new
  end

  def test_unknown_version_is_nil
    assert_nil @config.version_info("v9")
  end

  def test_versions_are_active_by_default
    @config.version("v2")
    info = @config.version_info("v2")
    assert info.active?
    refute info.signals_deprecation?
    refute info.signals_sunset?
  end

  def test_deprecated_without_a_date_defaults_to_now
    info = @config.version("v1", status: :deprecated)
    assert info.signals_deprecation?
    assert_kind_of Time, info.deprecation_on
  end

  def test_parses_bare_date_strings_as_utc_midnight
    @config.version("v1", deprecation: "2026-06-01", sunset: "2026-11-11")
    info = @config.version_info("v1")
    assert info.signals_deprecation?
    assert info.sunset_on.utc?
    assert_equal [2026, 11, 11, 0, 0, 0], [info.sunset_on.year, info.sunset_on.month,
                                           info.sunset_on.day, info.sunset_on.hour,
                                           info.sunset_on.min, info.sunset_on.sec]
  end

  def test_accepts_an_epoch_integer
    @config.version("v1", sunset: 1_700_000_000)
    assert_equal Time.at(1_700_000_000), @config.version_info("v1").sunset_on
  end

  def test_rejects_an_uninterpretable_date
    assert_raises(ArgumentError) { @config.version("v1", sunset: Object.new) }
  end

  def test_version_lookup_is_case_insensitive
    @config.version("V1", status: :deprecated)
    assert @config.version_info("v1").signals_deprecation?, "declared V1 should match v1"
    assert @config.version_info("V1").signals_deprecation?
  end
end
