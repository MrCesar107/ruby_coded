# frozen_string_literal: true

require "test_helper"
require "ruby_coded/plugins"
require "ruby_coded/chat/state"
require "ruby_coded/auth/auth_manager"

class TestLoginFlowState < Minitest::Test
  def setup
    @state = RubyCoded::Chat::State.new(model: "test-model")
  end

  # --- enter_login_flow! ---

  def test_enter_login_flow_without_provider_shows_provider_select
    @state.enter_login_flow!

    assert @state.login_active?
    assert_equal :provider_select, @state.login_step
    assert_equal 2, @state.login_items.size

    labels = @state.login_items.map { |i| i[:label] }
    assert_includes labels, "OpenAI"
    assert_includes labels, "Anthropic"
  end

  def test_enter_login_flow_with_openai_shows_auth_method_select
    @state.enter_login_flow!(provider: :openai)

    assert @state.login_active?
    assert_equal :auth_method_select, @state.login_step
    assert_equal :openai, @state.login_provider
    assert_equal 2, @state.login_items.size
  end

  def test_enter_login_flow_with_anthropic_skips_to_api_key
    @state.enter_login_flow!(provider: :anthropic)

    assert @state.login_active?
    assert_equal :api_key_input, @state.login_step
    assert_equal :anthropic, @state.login_provider
  end

  # --- Navigation ---

  def test_select_up_down_wraps
    @state.enter_login_flow!
    assert_equal 0, @state.login_select_index

    @state.login_select_down
    assert_equal 1, @state.login_select_index

    @state.login_select_down
    assert_equal 0, @state.login_select_index

    @state.login_select_up
    assert_equal 1, @state.login_select_index
  end

  def test_login_selected_item_returns_current
    @state.enter_login_flow!

    first = @state.login_selected_item
    assert_equal :openai, first[:key]

    @state.login_select_down
    second = @state.login_selected_item
    assert_equal :anthropic, second[:key]
  end

  # --- Step transitions ---

  def test_advance_to_auth_method
    @state.enter_login_flow!
    @state.login_advance_to_auth_method!(:openai)

    assert_equal :auth_method_select, @state.login_step
    assert_equal :openai, @state.login_provider
    assert_equal 2, @state.login_items.size
  end

  def test_advance_to_api_key
    @state.enter_login_flow!(provider: :openai)
    @state.login_advance_to_api_key!(:openai, :api_key)

    assert_equal :api_key_input, @state.login_step
    assert_equal :openai, @state.login_provider
    assert_equal :api_key, @state.login_auth_method
    assert_equal "", @state.login_key_buffer
  end

  def test_advance_to_oauth
    @state.enter_login_flow!(provider: :openai)
    @state.login_advance_to_oauth!(:openai)

    assert_equal :oauth_waiting, @state.login_step
    assert_equal :openai, @state.login_provider
    assert_equal :oauth, @state.login_auth_method
  end

  # --- API key buffer ---

  def test_append_and_delete_key_buffer
    @state.enter_login_flow!(provider: :anthropic)

    @state.append_to_login_key("sk-ant-")
    assert_equal "sk-ant-", @state.login_key_buffer
    assert_equal 7, @state.login_key_cursor

    @state.delete_last_login_key_char
    assert_equal "sk-ant", @state.login_key_buffer
    assert_equal 6, @state.login_key_cursor
  end

  def test_append_clears_error
    @state.enter_login_flow!(provider: :anthropic)
    @state.login_set_error!("bad key")
    assert_equal "bad key", @state.login_error

    @state.append_to_login_key("s")
    assert_nil @state.login_error
  end

  def test_delete_at_zero_is_noop
    @state.enter_login_flow!(provider: :anthropic)
    @state.delete_last_login_key_char
    assert_equal 0, @state.login_key_cursor
    assert_equal "", @state.login_key_buffer
  end

  # --- OAuth result ---

  def test_set_and_read_oauth_result
    @state.enter_login_flow!(provider: :openai)
    @state.login_advance_to_oauth!(:openai)

    assert_nil @state.login_oauth_result

    @state.login_set_oauth_result!({ code: "abc", state: "xyz" })
    assert_equal({ code: "abc", state: "xyz" }, @state.login_oauth_result)

    @state.login_clear_oauth_result!
    assert_nil @state.login_oauth_result
  end

  # --- Error ---

  def test_set_error
    @state.enter_login_flow!(provider: :anthropic)
    @state.login_set_error!("Invalid format")
    assert_equal "Invalid format", @state.login_error
  end

  # --- Exit ---

  def test_exit_login_flow_resets_everything
    @state.enter_login_flow!(provider: :openai)
    @state.login_advance_to_api_key!(:openai, :api_key)
    @state.append_to_login_key("sk-test")
    @state.login_set_error!("bad")

    @state.exit_login_flow!

    refute @state.login_active?
    assert_nil @state.login_step
    assert_nil @state.login_provider
    assert_nil @state.login_auth_method
    assert_empty @state.login_items
    assert_equal 0, @state.login_select_index
    assert_equal "", @state.login_key_buffer
    assert_equal 0, @state.login_key_cursor
    assert_nil @state.login_error
    assert_nil @state.login_oauth_result
  end

  # --- Provider module ---

  def test_login_provider_module
    @state.enter_login_flow!(provider: :openai)
    assert_equal RubyCoded::Auth::Providers::OpenAI, @state.login_provider_module

    @state.exit_login_flow!
    @state.enter_login_flow!(provider: :anthropic)
    assert_equal RubyCoded::Auth::Providers::Anthropic, @state.login_provider_module
  end

  # --- Mode isolation ---

  def test_login_does_not_interfere_with_other_modes
    refute @state.login_active?
    refute @state.model_select?
    assert_equal :chat, @state.mode
  end
end
