# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestStateCursor < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
  end

  def test_cursor_position_starts_at_zero
    assert_equal 0, @state.cursor_position
  end

  def test_append_to_input_advances_cursor
    @state.append_to_input("hello")
    assert_equal 5, @state.cursor_position
  end

  def test_append_inserts_at_cursor_position
    @state.append_to_input("helo")
    @state.move_cursor_left
    @state.append_to_input("l")

    assert_equal "hello", @state.input_buffer
    assert_equal 4, @state.cursor_position
  end

  def test_delete_last_char_at_end
    @state.append_to_input("hello")
    @state.delete_last_char

    assert_equal "hell", @state.input_buffer
    assert_equal 4, @state.cursor_position
  end

  def test_delete_last_char_at_middle
    @state.append_to_input("hello")
    @state.move_cursor_left
    @state.move_cursor_left
    @state.delete_last_char

    assert_equal "helo", @state.input_buffer
    assert_equal 2, @state.cursor_position
  end

  def test_delete_last_char_at_beginning_is_noop
    @state.append_to_input("hello")
    @state.move_cursor_to_start
    @state.delete_last_char

    assert_equal "hello", @state.input_buffer
    assert_equal 0, @state.cursor_position
  end

  def test_move_cursor_left
    @state.append_to_input("abc")
    @state.move_cursor_left
    assert_equal 2, @state.cursor_position
  end

  def test_move_cursor_left_clamps_at_zero
    @state.append_to_input("ab")
    @state.move_cursor_left
    @state.move_cursor_left
    @state.move_cursor_left

    assert_equal 0, @state.cursor_position
  end

  def test_move_cursor_right
    @state.append_to_input("abc")
    @state.move_cursor_left
    @state.move_cursor_left
    @state.move_cursor_right

    assert_equal 2, @state.cursor_position
  end

  def test_move_cursor_right_clamps_at_end
    @state.append_to_input("ab")
    @state.move_cursor_right

    assert_equal 2, @state.cursor_position
  end

  def test_move_cursor_to_start
    @state.append_to_input("hello")
    @state.move_cursor_to_start
    assert_equal 0, @state.cursor_position
  end

  def test_move_cursor_to_end
    @state.append_to_input("hello")
    @state.move_cursor_to_start
    @state.move_cursor_to_end
    assert_equal 5, @state.cursor_position
  end

  def test_clear_input_resets_cursor
    @state.append_to_input("hello")
    @state.clear_input!

    assert_equal "", @state.input_buffer
    assert_equal 0, @state.cursor_position
  end

  def test_consume_input_resets_cursor
    @state.append_to_input("hello")
    input = @state.consume_input!

    assert_equal "hello", input
    assert_equal "", @state.input_buffer
    assert_equal 0, @state.cursor_position
  end

  def test_insert_at_beginning
    @state.append_to_input("world")
    @state.move_cursor_to_start
    @state.append_to_input("hello ")

    assert_equal "hello world", @state.input_buffer
    assert_equal 6, @state.cursor_position
  end

  def test_multiple_inserts_at_various_positions
    @state.append_to_input("ad")
    @state.move_cursor_left
    @state.append_to_input("bc")

    assert_equal "abcd", @state.input_buffer
    assert_equal 3, @state.cursor_position
  end
end
