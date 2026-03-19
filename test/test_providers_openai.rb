# frozen_string_literal: true

require "test_helper"
require "ruby_code/auth/providers/openai"

class TestProvidersOpenAI < Minitest::Test
  def test_display_name
    assert_equal "OpenAI", provider.display_name
  end

  def test_client_id_is_codex_public_client
    assert_equal "app_EMoamEEZ73f0CkXaXp7hrann", provider.client_id
  end

  def test_auth_methods_includes_oauth_and_api_key
    methods = provider.auth_methods
    keys = methods.map { |m| m[:key] }

    assert_includes keys, :oauth
    assert_includes keys, :api_key
  end

  def test_auth_methods_have_labels
    provider.auth_methods.each do |method|
      assert method.key?(:label), "Method #{method[:key]} missing :label"
      refute_empty method[:label]
    end
  end

  def test_auth_url
    assert_equal "https://auth.openai.com/oauth/authorize", provider.auth_url
  end

  def test_token_url
    assert_equal "https://auth.openai.com/oauth/token", provider.token_url
  end

  def test_console_url
    assert_equal "https://platform.openai.com/account/api-keys", provider.console_url
  end

  def test_key_pattern_matches_valid_openai_keys
    assert provider.key_pattern.match?("sk-abc123")
    assert provider.key_pattern.match?("sk-proj-somethinglong")
  end

  def test_key_pattern_rejects_invalid_keys
    refute provider.key_pattern.match?("not-a-key")
    refute provider.key_pattern.match?("AIzaSomething")
    refute provider.key_pattern.match?("")
  end

  def test_redirect_uri
    assert_equal "http://localhost:18192/callback", provider.redirect_uri
  end

  def test_ruby_llm_key
    assert_equal :openai_api_key, provider.ruby_llm_key
  end

  private

  def provider
    RubyCode::Auth::Providers::OpenAI
  end
end
