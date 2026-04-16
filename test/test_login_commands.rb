# frozen_string_literal: true

require "test_helper"
require "ruby_coded/plugins"
require "ruby_coded/chat/command_handler"
require "ruby_coded/chat/state"
require "ruby_coded/auth/auth_manager"

class TestLoginCommands < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)

    @state = RubyCoded::Chat::State.new(model: "test-model")
    @llm_bridge = MockLoginBridge.new
    @handler = RubyCoded::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge
    )
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_login_without_args_enters_provider_select
    @handler.handle("/login")

    assert @state.login_active?
    assert_equal :provider_select, @state.login_step
    assert_equal 2, @state.login_items.size
  end

  def test_login_with_openai_enters_auth_method_select
    @handler.handle("/login openai")

    assert @state.login_active?
    assert_equal :auth_method_select, @state.login_step
    assert_equal :openai, @state.login_provider
  end

  def test_login_with_anthropic_enters_api_key_input
    @handler.handle("/login anthropic")

    assert @state.login_active?
    assert_equal :api_key_input, @state.login_step
    assert_equal :anthropic, @state.login_provider
  end

  def test_login_with_invalid_provider_shows_usage
    @handler.handle("/login fakeprovider")

    refute @state.login_active?
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Usage"
    assert_includes last_msg[:content], "openai"
    assert_includes last_msg[:content], "anthropic"
  end

  def test_login_provider_name_is_case_insensitive
    @handler.handle("/login OpenAI")

    assert @state.login_active?
    assert_equal :openai, @state.login_provider
  end

  def test_exit_login_flow_resets_state
    @state.enter_login_flow!
    assert @state.login_active?

    @state.exit_login_flow!
    refute @state.login_active?
    assert_nil @state.login_step
  end

  def test_help_includes_login_command
    @handler.handle("/help")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "/login"
  end

  class MockLoginBridge
    attr_reader :agentic_mode

    def initialize
      @agentic_mode = false
    end

    def toggle_agentic_mode!(enabled)
      @agentic_mode = enabled
    end

    def reset_agent_session!; end

    def reset_chat!(_model); end
  end
end
