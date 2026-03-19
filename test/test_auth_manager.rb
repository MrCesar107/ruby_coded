# frozen_string_literal: true

require "test_helper"
require "ruby_code/auth/auth_manager"

class TestAuthManager < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
    @manager = RubyCode::Auth::AuthManager.new
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_configured_providers_includes_openai
    assert_includes @manager.configured_providers, :openai
  end

  def test_configured_providers_returns_array_of_symbols
    @manager.configured_providers.each do |provider|
      assert_instance_of Symbol, provider
    end
  end

  def test_check_authentication_skips_when_credentials_exist
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    manager = RubyCode::Auth::AuthManager.new

    result = manager.check_authentication
    assert_nil result
  end

  def test_check_authentication_triggers_login_when_no_credentials
    strategy_mock = Minitest::Mock.new
    strategy_mock.expect(:authenticate, { "auth_method" => "api_key", "key" => "sk-test" })

    stub_prompt = build_stub_prompt(provider: :openai, method: :api_key)
    @manager.instance_variable_set(:@prompt, stub_prompt)

    RubyCode::Strategies::APIKeyStrategy.stub(:new, strategy_mock) do
      stub_ruby_llm_configure do
        @manager.check_authentication
      end
    end

    assert_equal "sk-test", credential_store.retrieve(:openai)["key"]
    strategy_mock.verify
  end

  def test_login_prompt_always_asks_even_with_existing_credentials
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-old" })
    manager = RubyCode::Auth::AuthManager.new

    strategy_mock = Minitest::Mock.new
    strategy_mock.expect(:authenticate, { "auth_method" => "api_key", "key" => "sk-new" })

    stub_prompt = build_stub_prompt(provider: :openai, method: :api_key)
    manager.instance_variable_set(:@prompt, stub_prompt)

    RubyCode::Strategies::APIKeyStrategy.stub(:new, strategy_mock) do
      stub_ruby_llm_configure do
        manager.login_prompt
      end
    end

    assert_equal "sk-new", credential_store.retrieve(:openai)["key"]
    strategy_mock.verify
  end

  def test_login_stores_credentials
    strategy_mock = Minitest::Mock.new
    strategy_mock.expect(:authenticate, { "auth_method" => "api_key", "key" => "sk-stored" })

    stub_prompt = build_stub_prompt(method: :api_key)
    @manager.instance_variable_set(:@prompt, stub_prompt)

    RubyCode::Strategies::APIKeyStrategy.stub(:new, strategy_mock) do
      stub_ruby_llm_configure do
        @manager.login(:openai)
      end
    end

    retrieved = credential_store.retrieve(:openai)
    assert_equal "api_key", retrieved["auth_method"]
    assert_equal "sk-stored", retrieved["key"]
  end

  def test_login_raises_for_unknown_provider
    assert_raises(KeyError) { @manager.login(:unknown_provider) }
  end

  def test_logout_removes_credentials
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    manager = RubyCode::Auth::AuthManager.new

    RubyLLM.stub(:configure, nil) do
      manager.logout(:openai)
    end

    assert_nil credential_store.retrieve(:openai)
  end

  def test_configure_ruby_llm_sets_api_key_from_api_key_credentials
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-from-config" })
    manager = RubyCode::Auth::AuthManager.new

    configured_key = nil
    RubyLLM.stub(:configure, ->(&block) {
      config = Minitest::Mock.new
      config.expect(:openai_api_key=, nil, ["sk-from-config"])
      block.call(config)
      configured_key = "sk-from-config"
      config.verify
    }) do
      manager.configure_ruby_llm!
    end

    assert_equal "sk-from-config", configured_key
  end

  def test_configure_ruby_llm_sets_access_token_from_oauth_credentials
    store_credentials(:openai, {
      "auth_method" => "oauth",
      "access_token" => "eyJoauth",
      "refresh_token" => "rt-test",
      "expires_at" => "2026-12-31T00:00:00Z"
    })
    manager = RubyCode::Auth::AuthManager.new

    configured_key = nil
    RubyLLM.stub(:configure, ->(&block) {
      config = Minitest::Mock.new
      config.expect(:openai_api_key=, nil, ["eyJoauth"])
      block.call(config)
      configured_key = "eyJoauth"
      config.verify
    }) do
      manager.configure_ruby_llm!
    end

    assert_equal "eyJoauth", configured_key
  end

  def test_configure_ruby_llm_skips_unconfigured_providers
    manager = RubyCode::Auth::AuthManager.new

    RubyLLM.stub(:configure, ->(&block) {
      config = Object.new
      block.call(config)
    }) do
      manager.configure_ruby_llm!
    end
  end

  private

  def stub_ruby_llm_configure(&block)
    fake_configure = ->(&config_block) {
      config = Struct.new(:openai_api_key).new
      config_block.call(config) if config_block
    }
    RubyLLM.stub(:configure, fake_configure, &block)
  end

  def build_stub_prompt(provider: nil, method: nil)
    select_responses = []
    select_responses << provider if provider
    select_responses << method if method

    stub_prompt = Object.new
    responses = select_responses.dup

    stub_prompt.define_singleton_method(:select) do |*_args, **_kwargs|
      responses.shift
    end

    stub_prompt
  end

  def store_credentials(provider_name, credentials)
    config = RubyCode::UserConfig.new
    cfg = config.full_config
    cfg["providers"] ||= {}
    cfg["providers"][provider_name.to_s] = credentials
    config.save
  end

  def credential_store
    RubyCode::Auth::CredentialsStore.new
  end
end
