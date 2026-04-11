# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestStateMessages < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
  end

  def test_add_message_appends_to_messages
    @state.add_message(:user, "Hello")

    assert_equal 1, @state.messages.size
    assert_equal :user, @state.messages.first[:role]
    assert_equal "Hello", @state.messages.first[:content]
  end

  def test_add_message_initializes_tokens_to_zero
    @state.add_message(:user, "Hello")

    msg = @state.messages.first
    assert_equal 0, msg[:input_tokens]
    assert_equal 0, msg[:output_tokens]
    assert_equal 0, msg[:thinking_tokens]
    assert_equal 0, msg[:cached_tokens]
    assert_equal 0, msg[:cache_creation_tokens]
  end

  def test_add_message_includes_timestamp
    @state.add_message(:user, "Hello")
    assert_instance_of Time, @state.messages.first[:timestamp]
  end

  def test_add_message_scrolls_to_bottom
    @state.add_message(:user, "one")
    @state.add_message(:user, "two")
    @state.update_scroll_metrics(total_lines: 20, visible_height: 10)
    @state.scroll_up
    refute_equal 0, @state.scroll_offset

    @state.add_message(:user, "three")
    assert_equal 0, @state.scroll_offset
  end

  def test_append_to_last_message
    @state.add_message(:assistant, "Hello")
    @state.append_to_last_message(" world")

    assert_equal "Hello world", @state.messages.last[:content]
  end

  def test_append_to_last_message_noop_when_empty
    @state.append_to_last_message("text")
    assert_empty @state.messages
  end

  def test_last_assistant_empty_true_when_no_messages
    assert @state.last_assistant_empty?
  end

  def test_last_assistant_empty_true_when_empty_content
    @state.add_message(:assistant, "")
    assert @state.last_assistant_empty?
  end

  def test_last_assistant_empty_false_when_has_content
    @state.add_message(:assistant, "Hello")
    refute @state.last_assistant_empty?
  end

  def test_last_assistant_empty_false_when_last_is_user
    @state.add_message(:user, "")
    refute @state.last_assistant_empty?
  end

  def test_reset_last_assistant_content_clears_content
    @state.add_message(:assistant, "some text")
    @state.reset_last_assistant_content

    assert_equal "", @state.messages.last[:content]
  end

  def test_reset_last_assistant_content_noop_for_user_message
    @state.add_message(:user, "text")
    @state.reset_last_assistant_content

    assert_equal "text", @state.messages.last[:content]
  end

  def test_reset_last_assistant_content_noop_when_empty
    @state.reset_last_assistant_content
    assert_empty @state.messages
  end

  def test_fail_last_assistant_with_friendly_message
    @state.add_message(:assistant, "")
    @state.fail_last_assistant(StandardError.new("err"), friendly_message: "Oops!")

    assert_equal "Oops!", @state.messages.last[:content]
  end

  def test_fail_last_assistant_with_default_message
    error = StandardError.new("connection failed")
    @state.add_message(:assistant, "")
    @state.fail_last_assistant(error)

    assert_includes @state.messages.last[:content], "StandardError"
    assert_includes @state.messages.last[:content], "connection failed"
  end

  def test_fail_last_assistant_appends_to_existing_content
    @state.add_message(:assistant, "Partial response")
    @state.fail_last_assistant(StandardError.new("err"), friendly_message: "Oops!")

    content = @state.messages.last[:content]
    assert_includes content, "Partial response"
    assert_includes content, "Oops!"
  end

  def test_fail_last_assistant_noop_for_user_message
    @state.add_message(:user, "text")
    @state.fail_last_assistant(StandardError.new("err"))

    assert_equal "text", @state.messages.last[:content]
  end

  def test_update_last_message_tokens
    @state.add_message(:user, "Hello")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 20)

    msg = @state.messages.last
    assert_equal 10, msg[:input_tokens]
    assert_equal 20, msg[:output_tokens]
  end

  def test_update_last_message_tokens_with_extended_fields
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(
      input_tokens: 100, output_tokens: 50,
      thinking_tokens: 500, cached_tokens: 200, cache_creation_tokens: 80
    )

    msg = @state.messages.last
    assert_equal 100, msg[:input_tokens]
    assert_equal 50, msg[:output_tokens]
    assert_equal 500, msg[:thinking_tokens]
    assert_equal 200, msg[:cached_tokens]
    assert_equal 80, msg[:cache_creation_tokens]
  end

  def test_update_last_message_tokens_nil_extended_fields_default_to_zero
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    msg = @state.messages.last
    assert_equal 0, msg[:thinking_tokens]
    assert_equal 0, msg[:cached_tokens]
    assert_equal 0, msg[:cache_creation_tokens]
  end

  def test_update_last_message_tokens_noop_when_empty
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 20)
    assert_empty @state.messages
  end

  def test_clear_messages_empties_list
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi")
    @state.clear_messages!

    assert_empty @state.messages
  end

  def test_clear_messages_resets_scroll
    @state.add_message(:user, "a")
    @state.add_message(:user, "b")
    @state.update_scroll_metrics(total_lines: 20, visible_height: 10)
    @state.scroll_up
    @state.clear_messages!

    assert_equal 0, @state.scroll_offset
  end

  def test_total_input_tokens
    @state.add_message(:user, "a")
    @state.update_last_message_tokens(input_tokens: 5, output_tokens: 0)
    @state.add_message(:user, "b")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 0)

    assert_equal 15, @state.total_input_tokens
  end

  def test_total_output_tokens
    @state.add_message(:assistant, "a")
    @state.update_last_message_tokens(input_tokens: 0, output_tokens: 8)
    @state.add_message(:assistant, "b")
    @state.update_last_message_tokens(input_tokens: 0, output_tokens: 12)

    assert_equal 20, @state.total_output_tokens
  end

  def test_total_tokens_zero_when_empty
    assert_equal 0, @state.total_input_tokens
    assert_equal 0, @state.total_output_tokens
    assert_equal 0, @state.total_thinking_tokens
  end

  def test_total_thinking_tokens
    @state.add_message(:assistant, "a")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 5, thinking_tokens: 100)
    @state.add_message(:assistant, "b")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 5, thinking_tokens: 200)

    assert_equal 300, @state.total_thinking_tokens
  end

  # --- update_last_message_tokens with model: parameter ---

  def test_update_last_message_tokens_tracks_by_default_model
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    usage = @state.token_usage_by_model
    assert_equal 100, usage["gpt-4o"][:input_tokens]
    assert_equal 50, usage["gpt-4o"][:output_tokens]
  end

  def test_update_last_message_tokens_tracks_by_explicit_model
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, model: "claude-sonnet")

    usage = @state.token_usage_by_model
    assert_equal 100, usage["claude-sonnet"][:input_tokens]
    assert_nil usage["gpt-4o"]
  end

  def test_update_last_message_tokens_accumulates_per_model
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)
    @state.add_message(:assistant, "B")
    @state.update_last_message_tokens(input_tokens: 200, output_tokens: 75)

    usage = @state.token_usage_by_model
    assert_equal 300, usage["gpt-4o"][:input_tokens]
    assert_equal 125, usage["gpt-4o"][:output_tokens]
  end

  def test_update_last_message_tokens_tracks_multiple_models
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, model: "model-a")
    @state.add_message(:assistant, "B")
    @state.update_last_message_tokens(input_tokens: 200, output_tokens: 75, model: "model-b")

    usage = @state.token_usage_by_model
    assert_equal 100, usage["model-a"][:input_tokens]
    assert_equal 50, usage["model-a"][:output_tokens]
    assert_equal 200, usage["model-b"][:input_tokens]
    assert_equal 75, usage["model-b"][:output_tokens]
  end

  def test_update_last_message_tokens_accumulates_extended_fields_per_model
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, thinking_tokens: 500,
                                      cached_tokens: 200, cache_creation_tokens: 80)
    @state.add_message(:assistant, "B")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, thinking_tokens: 300,
                                      cached_tokens: 100, cache_creation_tokens: 20)

    usage = @state.token_usage_by_model["gpt-4o"]
    assert_equal 800, usage[:thinking_tokens]
    assert_equal 300, usage[:cached_tokens]
    assert_equal 100, usage[:cache_creation_tokens]
  end

  # --- clear_messages! resets token usage ---

  def test_clear_messages_resets_token_usage_by_model
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)
    refute_empty @state.token_usage_by_model

    @state.clear_messages!
    assert_empty @state.token_usage_by_model
  end

  # --- token_usage_by_model returns independent copy ---

  def test_token_usage_by_model_returns_independent_copy
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    usage = @state.token_usage_by_model
    usage["gpt-4o"][:input_tokens] = 999

    assert_equal 100, @state.token_usage_by_model["gpt-4o"][:input_tokens]
  end

  def test_messages_snapshot_returns_independent_hashes
    @state.add_message(:user, "Hello")
    snapshot = @state.messages_snapshot

    snapshot.first[:role] = :changed
    assert_equal :user, @state.messages.first[:role]
  end

  def test_messages_snapshot_reflects_current_state
    @state.add_message(:user, "one")
    @state.add_message(:assistant, "two")

    snapshot = @state.messages_snapshot
    assert_equal 2, snapshot.size
    assert_equal :user, snapshot[0][:role]
    assert_equal :assistant, snapshot[1][:role]
  end

  # --- ensure_last_is_assistant! ---

  def test_ensure_last_is_assistant_creates_message_when_empty
    @state.ensure_last_is_assistant!

    assert_equal 1, @state.messages.size
    assert_equal :assistant, @state.messages.last[:role]
    assert_equal "", @state.messages.last[:content]
  end

  def test_ensure_last_is_assistant_noop_when_last_is_assistant
    @state.add_message(:assistant, "existing")
    @state.ensure_last_is_assistant!

    assert_equal 1, @state.messages.size
    assert_equal "existing", @state.messages.last[:content]
  end

  def test_ensure_last_is_assistant_adds_after_tool_result
    @state.add_message(:assistant, "initial")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.add_message(:tool_result, "class App; end")
    @state.ensure_last_is_assistant!

    assert_equal 4, @state.messages.size
    assert_equal :assistant, @state.messages.last[:role]
    assert_equal "", @state.messages.last[:content]
  end

  def test_streaming_after_tool_result_lands_in_new_assistant
    @state.add_message(:assistant, "Let me check")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.add_message(:tool_result, "file contents")

    @state.ensure_last_is_assistant!
    @state.append_to_last_message("Here is the result.")

    assert_equal :assistant, @state.messages.last[:role]
    assert_equal "Here is the result.", @state.messages.last[:content]
    assert_equal "file contents", @state.messages[2][:content]
  end
end
