# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"
require "ruby_code/chat/command_handler/history_commands"

class TestHistoryCommands < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @host = HistoryCommandsHost.new(@state)
  end

  def test_cmd_history_shows_empty_message_when_no_conversation
    @host.cmd_history(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "No conversation history yet."
  end

  def test_cmd_history_excludes_system_messages
    @state.add_message(:system, "System info")
    @host.cmd_history(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "No conversation history yet."
  end

  def test_cmd_history_shows_user_and_assistant_messages
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi there")
    @host.cmd_history(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Conversation history (2 messages)"
    assert_includes last_msg[:content], "[User] Hello"
    assert_includes last_msg[:content], "[Assistant] Hi there"
  end

  def test_cmd_history_numbers_messages
    @state.add_message(:user, "First")
    @state.add_message(:assistant, "Second")
    @host.cmd_history(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "1. [User] First"
    assert_includes last_msg[:content], "2. [Assistant] Second"
  end

  def test_cmd_history_truncates_long_messages
    long_text = "A" * 100
    @state.add_message(:user, long_text)
    @host.cmd_history(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "..."
    refute_includes last_msg[:content], "A" * 100
  end

  def test_cmd_history_uses_first_line_as_preview
    @state.add_message(:user, "First line\nSecond line\nThird line")
    @host.cmd_history(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "[User] First line"
    refute_includes last_msg[:content], "Second line"
  end

  def test_cmd_tokens_shows_zero_usage
    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "0 input, 0 output (0 total)"
  end

  def test_cmd_tokens_shows_accumulated_usage
    @state.add_message(:user, "Hello")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 0)
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 0, output_tokens: 25)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "10 input, 25 output (35 total)"
  end


  class HistoryCommandsHost
    include RubyCode::Chat::CommandHandler::HistoryCommands

    def initialize(state)
      @state = state
    end

    public :cmd_history, :cmd_tokens
  end
end
