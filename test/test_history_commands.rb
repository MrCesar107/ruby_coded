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

  # --- cmd_tokens: detailed cost report ---

  def test_cmd_tokens_shows_no_usage_message_when_empty
    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "No token usage recorded yet."
  end

  def test_cmd_tokens_shows_report_header
    @state.add_message(:user, "Hello")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 5)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Session Token Usage & Cost Report"
    assert_includes last_msg[:content], "═" * 50
  end

  def test_cmd_tokens_shows_model_name_in_breakdown
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Model: gpt-4o"
  end

  def test_cmd_tokens_shows_token_counts
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "100 tokens"
    assert_includes last_msg[:content], "50 tokens"
    assert_includes last_msg[:content], "Subtotal: 150 tokens"
  end

  def test_cmd_tokens_shows_thinking_tokens_when_present
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, thinking_tokens: 500)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Thinking: 500 tokens"
  end

  def test_cmd_tokens_hides_thinking_when_zero
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    refute_includes last_msg[:content], "Thinking:"
  end

  def test_cmd_tokens_shows_totals_line
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Total: 150 tokens"
    assert_includes last_msg[:content], "↑100"
    assert_includes last_msg[:content], "↓50"
    assert_includes last_msg[:content], "─" * 50
  end

  def test_cmd_tokens_totals_include_thinking
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, thinking_tokens: 500)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Total: 650 tokens"
    assert_includes last_msg[:content], "💭500"
  end

  def test_cmd_tokens_shows_pricing_unavailable_for_unknown_model
    @state = RubyCode::Chat::State.new(model: "unknown-model-xyz")
    @host = HistoryCommandsHost.new(@state)

    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "(pricing unavailable)"
  end

  def test_cmd_tokens_accumulates_across_messages
    @state.add_message(:user, "Hello")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 0)
    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 0, output_tokens: 25)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Total: 35 tokens (↑10 ↓25)"
  end

  def test_cmd_tokens_shows_cost_na_when_no_pricing
    @state = RubyCode::Chat::State.new(model: "unknown-model-xyz")
    @host = HistoryCommandsHost.new(@state)

    @state.add_message(:assistant, "Hi")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @host.cmd_tokens(nil)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Cost: N/A"
  end

  # --- format_num ---

  def test_format_num_small_number
    assert_equal "42", @host.format_num(42)
  end

  def test_format_num_thousands
    assert_equal "1,234", @host.format_num(1234)
  end

  def test_format_num_millions
    assert_equal "1,234,567", @host.format_num(1_234_567)
  end

  def test_format_num_zero
    assert_equal "0", @host.format_num(0)
  end

  def test_format_num_hundred
    assert_equal "100", @host.format_num(100)
  end

  # --- format_usd ---

  def test_format_usd_nil
    assert_equal "N/A", @host.format_usd(nil)
  end

  def test_format_usd_tiny_amount
    assert_equal "$0.00", @host.format_usd(0.000025)
  end

  def test_format_usd_small_amount
    assert_equal "$0.05", @host.format_usd(0.05)
  end

  def test_format_usd_large_amount
    assert_equal "$1.50", @host.format_usd(1.50)
  end

  def test_format_usd_zero
    assert_equal "$0.00", @host.format_usd(0.0)
  end

  class HistoryCommandsHost
    include RubyCode::Chat::CommandHandler::HistoryCommands
    include RubyCode::Chat::CommandHandler::TokenCommands
    include RubyCode::Chat::CommandHandler::TokenFormatting

    def initialize(state)
      @state = state
    end

    public :cmd_history, :cmd_tokens, :format_num, :format_usd
  end
end
