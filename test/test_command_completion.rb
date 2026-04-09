# frozen_string_literal: true

require "test_helper"
require "ruby_code/plugins"
require "ruby_code/chat/state"

class TestCommandCompletion < Minitest::Test
  def setup
    @registry = RubyCode::Plugins::Registry.new
    @registry.register(RubyCode::Plugins::CommandCompletion::Plugin)

    state_class = build_state_class
    @registry.apply_extensions!(
      state_class: state_class,
      input_handler_class: Class.new,
      renderer_class: Class.new,
      command_handler_class: Class.new
    )
    @state = state_class.new(model: "test-model")
  end

  # --- Activation ---

  def test_not_active_when_buffer_empty
    refute @state.command_completion_active?
  end

  def test_not_active_when_buffer_has_no_slash
    @state.append_to_input("hello")
    refute @state.command_completion_active?
  end

  def test_active_when_buffer_is_just_slash
    @state.append_to_input("/")
    assert @state.command_completion_active?
  end

  def test_active_when_buffer_has_partial_command
    @state.append_to_input("/he")
    assert @state.command_completion_active?
  end

  def test_not_active_when_buffer_has_space
    @state.append_to_input("/model gpt")
    refute @state.command_completion_active?
  end

  def test_not_active_when_no_match
    @state.append_to_input("/zzz")
    refute @state.command_completion_active?
  end

  # --- Suggestions ---

  def test_slash_shows_all_commands
    @state.append_to_input("/")
    suggestions = @state.command_suggestions
    commands = suggestions.map(&:first)
    assert_includes commands, "/help"
    assert_includes commands, "/model"
    assert_includes commands, "/exit"
    assert_includes commands, "/clear"
    assert_includes commands, "/history"
    assert_includes commands, "/tokens"
    assert_includes commands, "/quit"
  end

  def test_suggestions_filtered_by_prefix
    @state.append_to_input("/mo")
    suggestions = @state.command_suggestions
    assert_equal 1, suggestions.size
    assert_equal "/model", suggestions.first.first
  end

  def test_suggestions_are_sorted
    @state.append_to_input("/")
    commands = @state.command_suggestions.map(&:first)
    assert_equal commands.sort, commands
  end

  def test_suggestions_include_descriptions
    @state.append_to_input("/he")
    cmd, desc = @state.command_suggestions.first
    assert_equal "/help", cmd
    assert_equal "Show help message", desc
  end

  def test_filtering_is_case_insensitive
    @state.append_to_input("/HE")
    suggestions = @state.command_suggestions
    commands = suggestions.map(&:first)
    assert_includes commands, "/help"
  end

  # --- Navigation ---

  def test_initial_index_is_zero
    assert_equal 0, @state.command_completion_index
  end

  def test_navigation_down
    @state.append_to_input("/")
    @state.command_completion_down
    assert_equal 1, @state.command_completion_index
  end

  def test_navigation_up_wraps_around
    @state.append_to_input("/")
    @state.command_completion_up
    expected = @state.command_suggestions.size - 1
    assert_equal expected, @state.command_completion_index
  end

  def test_navigation_down_wraps_around
    @state.append_to_input("/")
    count = @state.command_suggestions.size
    count.times { @state.command_completion_down }
    assert_equal 0, @state.command_completion_index
  end

  def test_current_suggestion_follows_index
    @state.append_to_input("/")
    first_cmd = @state.command_suggestions[0].first
    assert_equal first_cmd, @state.current_command_suggestion.first

    @state.command_completion_down
    second_cmd = @state.command_suggestions[1].first
    assert_equal second_cmd, @state.current_command_suggestion.first
  end

  # --- Accept ---

  def test_accept_replaces_buffer
    @state.append_to_input("/mo")
    @state.accept_command_completion!
    assert_equal "/model", @state.input_buffer
  end

  def test_accept_resets_index
    @state.append_to_input("/")
    @state.command_completion_down
    @state.command_completion_down
    @state.accept_command_completion!
    assert_equal 0, @state.command_completion_index
  end

  def test_accept_with_navigated_selection
    @state.append_to_input("/")
    sorted = @state.command_suggestions
    @state.command_completion_down
    expected = sorted[1].first
    @state.accept_command_completion!
    assert_equal expected, @state.input_buffer
  end

  # --- Index reset on buffer change ---

  def test_typing_resets_index
    @state.append_to_input("/")
    @state.command_completion_down
    @state.command_completion_down
    assert @state.command_completion_index.positive?

    @state.append_to_input("h")
    assert_equal 0, @state.command_completion_index
  end

  def test_backspace_resets_index
    @state.append_to_input("/")
    @state.command_completion_down
    @state.command_completion_down
    assert @state.command_completion_index.positive?

    @state.delete_last_char
    assert_equal 0, @state.command_completion_index
  end

  private

  def build_state_class
    Class.new(RubyCode::Chat::State) do
      # Isolated subclass so plugin modules don't leak between tests.
    end
  end
end
