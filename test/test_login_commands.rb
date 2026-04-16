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

  def test_login_without_args_requests_tui_suspend
    @handler.handle("/login")

    assert @state.tui_suspend_requested?
    assert_equal :login, @state.tui_suspend_reason
    assert_equal({}, @state.tui_suspend_metadata)
  end

  def test_login_with_valid_provider_requests_suspend_with_provider
    @handler.handle("/login openai")

    assert @state.tui_suspend_requested?
    assert_equal :login, @state.tui_suspend_reason
    assert_equal({ provider: :openai }, @state.tui_suspend_metadata)
  end

  def test_login_with_anthropic_provider
    @handler.handle("/login anthropic")

    assert @state.tui_suspend_requested?
    assert_equal :login, @state.tui_suspend_reason
    assert_equal({ provider: :anthropic }, @state.tui_suspend_metadata)
  end

  def test_login_with_invalid_provider_shows_usage
    @handler.handle("/login fakeprovider")

    refute @state.tui_suspend_requested?
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Usage"
    assert_includes last_msg[:content], "openai"
    assert_includes last_msg[:content], "anthropic"
  end

  def test_login_provider_name_is_case_insensitive
    @handler.handle("/login OpenAI")

    assert @state.tui_suspend_requested?
    assert_equal({ provider: :openai }, @state.tui_suspend_metadata)
  end

  def test_clear_tui_suspend_resets_state
    @state.request_tui_suspend!(:login, provider: :openai)
    assert @state.tui_suspend_requested?

    @state.clear_tui_suspend!
    refute @state.tui_suspend_requested?
    assert_nil @state.tui_suspend_reason
    assert_equal({}, @state.tui_suspend_metadata)
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
