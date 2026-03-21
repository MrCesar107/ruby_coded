# frozen_string_literal: true

require "test_helper"
require "ruby_code/auth/providers/anthropic"

class TestProvidersAnthropic < Minitest::Test
  def test_display_name
    assert_equal "Anthropic", provider.display_name
  end

  def test_auth_methods_includes_only_api_key
    methods = provider.auth_methods
    keys = methods.map { |m| m[:key] }

    assert_includes keys, :api_key
    assert_equal 1, keys.size
  end

  def test_auth_methods_have_labels
    provider.auth_methods.each do |method|
      assert method.key?(:label), "Method #{method[:key]} missing :label"
      refute_empty method[:label]
    end
  end

  def test_console_url
    assert_equal "https://console.anthropic.com/settings/keys", provider.console_url
  end

  def test_key_pattern_matches_valid_anthropic_keys
    assert provider.key_pattern.match?("sk-ant-api03-abc123")
    assert provider.key_pattern.match?("sk-ant-something-else")
  end

  def test_key_pattern_rejects_invalid_keys
    refute provider.key_pattern.match?("sk-abc123")
    refute provider.key_pattern.match?("not-a-key")
    refute provider.key_pattern.match?("")
  end

  def test_ruby_llm_key
    assert_equal :anthropic_api_key, provider.ruby_llm_key
  end

  def test_does_not_respond_to_oauth_methods
    refute provider.respond_to?(:auth_url)
    refute provider.respond_to?(:token_url)
    refute provider.respond_to?(:redirect_uri)
    refute provider.respond_to?(:scopes)
    refute provider.respond_to?(:client_id)
  end

  private

  def provider
    RubyCode::Auth::Providers::Anthropic
  end
end
