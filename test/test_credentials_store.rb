# frozen_string_literal: true

require "test_helper"
require "ruby_code/auth/credentials_store"

class TestCredentialsStore < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
    @store = RubyCode::Auth::CredentialsStore.new
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_retrieve_returns_nil_when_no_providers_exist
    assert_nil @store.retrieve(:openai)
  end

  def test_retrieve_returns_nil_for_unknown_provider
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    assert_nil @store.retrieve(:anthropic)
  end

  def test_store_and_retrieve_api_key_credentials
    credentials = { "auth_method" => "api_key", "key" => "sk-test123" }
    @store.store(:openai, credentials)

    retrieved = @store.retrieve(:openai)
    assert_equal "api_key", retrieved["auth_method"]
    assert_equal "sk-test123", retrieved["key"]
  end

  def test_store_and_retrieve_oauth_credentials
    credentials = {
      "auth_method" => "oauth",
      "access_token" => "eyJtoken",
      "refresh_token" => "rt-refresh",
      "expires_at" => "2026-12-31T00:00:00Z"
    }
    @store.store(:openai, credentials)

    retrieved = @store.retrieve(:openai)
    assert_equal "oauth", retrieved["auth_method"]
    assert_equal "eyJtoken", retrieved["access_token"]
    assert_equal "rt-refresh", retrieved["refresh_token"]
  end

  def test_store_persists_to_config_file
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-persisted" })

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal "sk-persisted", raw.dig("providers", "openai", "key")
  end

  def test_store_preserves_existing_user_config
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-test" })

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert raw.key?("user_config")
    assert_equal false, raw["user_config"]["current_directory_permission"]
  end

  def test_store_does_not_overwrite_other_providers
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-openai" })
    @store.store(:anthropic, { "auth_method" => "api_key", "key" => "sk-ant-test" })

    assert_equal "sk-openai", @store.retrieve(:openai)["key"]
    assert_equal "sk-ant-test", @store.retrieve(:anthropic)["key"]
  end

  def test_store_overwrites_same_provider
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-old" })
    @store.store(:openai, { "auth_method" => "oauth", "access_token" => "new-token" })

    retrieved = @store.retrieve(:openai)
    assert_equal "oauth", retrieved["auth_method"]
    assert_nil retrieved["key"]
  end

  def test_remove_deletes_provider_credentials
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    @store.remove(:openai)

    assert_nil @store.retrieve(:openai)
  end

  def test_remove_does_not_crash_when_no_providers_exist
    @store.remove(:openai)
    assert_nil @store.retrieve(:openai)
  end

  def test_remove_preserves_other_providers
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-openai" })
    @store.store(:anthropic, { "auth_method" => "api_key", "key" => "sk-ant-test" })
    @store.remove(:openai)

    assert_nil @store.retrieve(:openai)
    assert_equal "sk-ant-test", @store.retrieve(:anthropic)["key"]
  end

  def test_remove_persists_deletion_to_file
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    @store.remove(:openai)

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_nil raw.dig("providers", "openai")
  end

  def test_retrieve_works_with_symbol_and_stores_as_string
    @store.store(:openai, { "auth_method" => "api_key", "key" => "sk-test" })

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert raw["providers"].key?("openai")
    assert_equal "sk-test", @store.retrieve(:openai)["key"]
  end
end
