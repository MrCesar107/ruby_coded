# frozen_string_literal: true

require "test_helper"
require "ruby_code/version"

class TestRubyCode < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RubyCode::VERSION
  end

  def test_version_is_a_string
    assert_instance_of String, RubyCode::VERSION
  end

  def test_version_follows_semver_format
    assert_match(/\A\d+\.\d+\.\d+\z/, RubyCode::VERSION)
  end

  def test_gem_version_returns_gem_version_object
    assert_instance_of Gem::Version, RubyCode.gem_version
  end

  def test_gem_version_matches_version_constant
    assert_equal Gem::Version.new(RubyCode::VERSION), RubyCode.gem_version
  end
end
