# frozen_string_literal: true

require "test_helper"
require "ruby_code/auth/providers/openai"
require "ruby_code/strategies/api_key_strategy"

class TestAPIKeyStrategy < Minitest::Test
  def setup
    @provider = RubyCode::Auth::Providers::OpenAI
    @strategy = RubyCode::Strategies::APIKeyStrategy.new(@provider)
  end

  def test_authenticate_returns_credentials_with_valid_key
    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:say, nil, [String])
    mock_prompt.expect(:ask, "sk-test123", [String])
    mock_prompt.expect(:say, nil, [String])

    @strategy.stub(:open_browser, nil) do
      @strategy.instance_variable_set(:@prompt, mock_prompt)
      result = @strategy.authenticate

      assert_equal "api_key", result["auth_method"]
      assert_equal "sk-test123", result["key"]
    end

    mock_prompt.verify
  end

  def test_authenticate_raises_on_nil_key
    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:say, nil, [String])
    mock_prompt.expect(:ask, nil, [String])

    @strategy.stub(:open_browser, nil) do
      @strategy.instance_variable_set(:@prompt, mock_prompt)

      assert_raises(RuntimeError) { @strategy.authenticate }
    end
  end

  def test_authenticate_raises_on_empty_key
    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:say, nil, [String])
    mock_prompt.expect(:ask, "", [String])

    @strategy.stub(:open_browser, nil) do
      @strategy.instance_variable_set(:@prompt, mock_prompt)

      assert_raises(RuntimeError) { @strategy.authenticate }
    end
  end

  def test_authenticate_raises_on_invalid_format
    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:say, nil, [String])
    mock_prompt.expect(:ask, "not-a-valid-key", [String])

    @strategy.stub(:open_browser, nil) do
      @strategy.instance_variable_set(:@prompt, mock_prompt)

      assert_raises(RuntimeError) { @strategy.authenticate }
    end
  end

  def test_refresh_returns_credentials_unchanged
    credentials = { "auth_method" => "api_key", "key" => "sk-test" }
    assert_equal credentials, @strategy.refresh(credentials)
  end

  def test_validate_returns_true_for_valid_api_key_credentials
    credentials = { "auth_method" => "api_key", "key" => "sk-valid123" }
    assert @strategy.validate(credentials)
  end

  def test_validate_returns_false_for_wrong_auth_method
    credentials = { "auth_method" => "oauth", "key" => "sk-valid123" }
    refute @strategy.validate(credentials)
  end

  def test_validate_returns_false_for_invalid_key_format
    credentials = { "auth_method" => "api_key", "key" => "invalid-key" }
    refute @strategy.validate(credentials)
  end

  def test_validate_returns_false_for_nil_key
    credentials = { "auth_method" => "api_key", "key" => nil }
    refute @strategy.validate(credentials)
  end
end
