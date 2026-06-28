# frozen_string_literal: true

require "test_helper"
require "ruby_coded/version"
require "ruby_coded/chat/state"
require "ruby_coded/chat/renderer/chat_panel_formatting"
require "ruby_coded/chat/renderer/chat_panel_sections"
require "ruby_coded/chat/renderer/chat_panel"
require "ruby_coded/chat/renderer/chat_panel_input"
require "ruby_coded/chat/renderer/chat_panel_thinking"

class TestRendererChatPanel < Minitest::Test
  def setup
    @state = RubyCoded::Chat::State.new(model: "gpt-4o")
    @tui = MockTui.new
    @host = ChatPanelHost.new(@tui, @state)
  end

  def test_chat_panel_text_returns_banner_when_no_messages
    text = @host.chat_panel_text
    assert_includes text, "v#{RubyCoded::VERSION}"
  end

  def test_chat_panel_text_formats_messages
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi there")

    text = @host.chat_panel_text
    assert_includes text, "[YOU] Hello"
    assert_includes text, "Hi there"
  end

  def test_chat_panel_text_joins_messages_with_newlines
    @state.add_message(:user, "one")
    @state.add_message(:user, "two")

    text = @host.chat_panel_text
    lines = text.split("\n").reject(&:empty?)
    assert_equal 2, lines.size
  end

  def test_render_chat_panel_creates_paragraph_with_model_title
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, rendered_area = frame.rendered.first
    assert_equal area, rendered_area
    assert_equal "gpt-4o", widget[:block][:title]
    assert_equal [:all], widget[:block][:borders]
  end

  def test_render_chat_panel_enables_wrap_for_messages
    @state.add_message(:user, "Hello")
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    widget, = frame.rendered.last
    assert_equal true, widget[:wrap]
  end

  def test_render_chat_panel_disables_wrap_for_banner
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    widget, = frame.rendered.first
    assert_equal false, widget[:wrap]
  end

  def test_render_chat_panel_scroll_at_bottom_by_default
    @state.add_message(:user, "Hello")
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    widget, = frame.rendered.last
    scroll_y, scroll_x = widget[:scroll]
    assert_equal 0, scroll_x
    assert_operator scroll_y, :>=, 0
  end

  def test_render_chat_panel_updates_scroll_metrics
    20.times { |i| @state.add_message(:user, "Line #{i}") }
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 10)

    @host.render_chat_panel(frame, area)

    @state.scroll_to_top
    assert_operator @state.scroll_offset, :>, 0
  end

  def test_render_chat_panel_highlights_user_messages
    @state.add_message(:user, "Highlight me")

    text = @host.chat_panel_text

    assert_includes text, "[YOU] Highlight me"
  end

  def test_render_chat_panel_shows_sticky_header_when_scrolled_into_response_block
    @state.add_message(:user, "First prompt")
    12.times { |i| @state.add_message(:assistant, "First response line #{i}") }
    @state.add_message(:user, "Second prompt")
    @state.add_message(:assistant, "Second response")

    frame = MockFrame.new
    area = MockArea.new(width: 30, height: 8)

    @host.render_chat_panel(frame, area)
    @state.scroll_up(6)

    frame = MockFrame.new
    @host.render_chat_panel(frame, area)

    assert_equal 2, frame.rendered.size
    sticky_widget, = frame.rendered[0]
    body_widget, = frame.rendered[1]
    assert_equal "current prompt", sticky_widget[:block][:title]
    assert_includes sticky_widget[:text], "[YOU] First prompt"
    assert_includes body_widget[:text], "[YOU] First prompt"
  end

  def test_render_chat_panel_updates_sticky_header_for_next_section
    @state.add_message(:user, "First prompt")
    8.times { |i| @state.add_message(:assistant, "First response line #{i}") }
    @state.add_message(:user, "Second prompt")
    8.times { |i| @state.add_message(:assistant, "Second response line #{i}") }

    area = MockArea.new(width: 30, height: 8)
    @host.render_chat_panel(MockFrame.new, area)
    @state.scroll_up(2)

    frame = MockFrame.new
    @host.render_chat_panel(frame, area)

    sticky_widget, = frame.rendered[0]
    assert_includes sticky_widget[:text], "[YOU] Second prompt"
    refute_includes sticky_widget[:text], "[YOU] First prompt"
  end

  def test_render_chat_panel_hides_sticky_header_when_user_prompt_is_at_top
    @state.add_message(:user, "Prompt")
    6.times { |i| @state.add_message(:assistant, "Response line #{i}") }

    frame = MockFrame.new
    area = MockArea.new(width: 30, height: 8)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, = frame.rendered.first
    assert_equal "gpt-4o", widget[:block][:title]
    refute_equal "current prompt", widget[:block][:title]
  end

  def test_render_chat_panel_no_sticky_header_without_user_messages
    @state.add_message(:assistant, "Hello")
    @state.add_message(:assistant, "World")
    frame = MockFrame.new
    area = MockArea.new(width: 30, height: 8)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, = frame.rendered.first
    assert_equal "gpt-4o", widget[:block][:title]
  end

  # --- Thinking panel: <think> tags ---

  def test_render_chat_panel_shows_thinking_panel_during_streaming
    @state.add_message(:user, "Explain ruby")
    @state.add_message(:assistant, "<think>Let me reason about this...")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 2, frame.rendered.size
    chat_widget, = frame.rendered[0]
    thinking_widget, = frame.rendered[1]

    assert_equal "gpt-4o", chat_widget[:block][:title]
    assert_equal "thinking...", thinking_widget[:block][:title]
    assert_includes thinking_widget[:text], "Let me reason about this..."
  end

  def test_thinking_panel_excludes_streaming_message_from_main_chat
    @state.add_message(:user, "Explain ruby")
    @state.add_message(:assistant, "<think>reasoning...")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    chat_widget, = frame.rendered[0]
    assert_includes chat_widget[:text], "[YOU] Explain ruby"
    refute_includes chat_widget[:text], "reasoning..."
  end

  def test_thinking_panel_disappears_when_think_tag_closes
    @state.add_message(:user, "Explain ruby")
    @state.add_message(:assistant, "<think>reasoning...</think>\nThe answer is 42.")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, = frame.rendered.first
    assert_includes widget[:text], "The answer is 42."
    refute_includes widget[:text], "reasoning..."
    refute_includes widget[:text], "<think>"
  end

  def test_thinking_panel_disappears_after_streaming_ends
    @state.add_message(:user, "Explain ruby")
    @state.add_message(:assistant, "<think>reasoning...</think>\nFinal result.")
    @state.streaming = false

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, = frame.rendered.first
    assert_includes widget[:text], "Final result."
    refute_includes widget[:text], "reasoning..."
  end

  def test_strip_think_tags_from_completed_assistant_messages
    @state.add_message(:assistant, "<think>internal thought</think>Visible answer")

    text = @host.chat_panel_text
    assert_includes text, "Visible answer"
    refute_includes text, "internal thought"
    refute_includes text, "<think>"
    refute_includes text, "</think>"
  end

  def test_no_thinking_panel_without_think_tags
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Normal streaming response")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
  end

  def test_thinking_panel_auto_scrolls_to_bottom
    long_thinking = (1..50).map { |i| "thinking line #{i}" }.join("\n")
    @state.add_message(:assistant, "<think>#{long_thinking}")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    thinking_widget, = frame.rendered[1]
    scroll_y, = thinking_widget[:scroll]
    assert_operator scroll_y, :>, 0, "Thinking panel should auto-scroll for long content"
  end

  # --- Thinking panel: agent tool activity ---

  def test_tool_calls_trigger_thinking_panel_during_streaming
    @state.add_message(:user, "Fix the bug")
    @state.add_message(:assistant, "Let me look at the file")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 2, frame.rendered.size
    thinking_widget, = frame.rendered[1]
    assert_equal "thinking...", thinking_widget[:block][:title]
    assert_includes thinking_widget[:text], "Let me look at the file"
    assert_includes thinking_widget[:text], ">> [read_file] path: app.rb"
  end

  def test_tool_results_shown_in_thinking_panel
    @state.add_message(:user, "Read the file")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.add_message(:tool_result, "class App; end")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    thinking_widget, = frame.rendered[1]
    assert_includes thinking_widget[:text], ">> [read_file] path: app.rb"
    assert_includes thinking_widget[:text], "   class App; end"
  end

  def test_tool_pending_shown_in_thinking_panel
    @state.add_message(:user, "Edit the file")
    @state.add_message(:tool_pending, "[WRITE] edit_file(path: app.rb) -- [y] approve / [n] reject")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    thinking_widget, = frame.rendered[1]
    assert_includes thinking_widget[:text], "?? [WRITE] edit_file"
  end

  def test_prior_messages_shown_in_main_chat_during_agent_cycle
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi!")
    @state.add_message(:user, "Fix the bug")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    chat_widget, = frame.rendered[0]
    assert_includes chat_widget[:text], "[YOU] Hello"
    assert_includes chat_widget[:text], "Hi!"
    assert_includes chat_widget[:text], "[YOU] Fix the bug"
    refute_includes chat_widget[:text], "read_file"
  end

  def test_tool_messages_hidden_from_main_chat_after_streaming
    @state.add_message(:user, "Fix the bug")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.add_message(:tool_result, "class App; end")
    @state.add_message(:assistant, "I fixed the bug.")
    @state.streaming = false

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, = frame.rendered.first
    assert_includes widget[:text], "[YOU] Fix the bug"
    assert_includes widget[:text], "I fixed the bug."
    refute_includes widget[:text], "read_file"
    refute_includes widget[:text], "class App; end"
  end

  def test_tool_messages_hidden_from_chat_panel_text
    @state.add_message(:user, "Fix it")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.add_message(:tool_result, "contents")
    @state.add_message(:assistant, "Done!")

    text = @host.chat_panel_text
    assert_includes text, "[YOU] Fix it"
    assert_includes text, "Done!"
    refute_includes text, "read_file"
    refute_includes text, "contents"
  end

  def test_mixed_think_tags_and_tool_calls_in_thinking_panel
    @state.add_message(:user, "Fix the bug")
    @state.add_message(:assistant, "<think>I need to read the file first")
    @state.add_message(:tool_call, "[read_file] path: app.rb")
    @state.add_message(:tool_result, "class App; end")
    @state.streaming = true

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 24)

    @host.render_chat_panel(frame, area)

    assert_equal 2, frame.rendered.size
    thinking_widget, = frame.rendered[1]
    assert_includes thinking_widget[:text], "I need to read the file first"
    assert_includes thinking_widget[:text], ">> [read_file] path: app.rb"
    assert_includes thinking_widget[:text], "   class App; end"
    refute_includes thinking_widget[:text], "<think>"
  end

  def test_only_result_assistant_message_empty_after_think_only
    @state.add_message(:assistant, "<think>pure thinking only</think>")

    text = @host.chat_panel_text
    refute_includes text, "pure thinking only"
    refute_includes text, "<think>"
  end

  # --- Input panel tests ---

  def test_render_input_panel_shows_prompt_with_buffer
    @state.append_to_input("hello world")
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 3)

    @host.render_input_panel(frame, area)

    widget, = frame.rendered.first
    assert_equal "ruby_coded> hello world", widget[:text]
  end

  def test_render_input_panel_shows_empty_prompt
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 3)

    @host.render_input_panel(frame, area)

    widget, = frame.rendered.first
    assert_equal "ruby_coded> ", widget[:text]
  end

  def test_render_input_panel_sets_cursor_at_end_of_input
    @state.append_to_input("hello")
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 3, x: 0, y: 21)

    @host.render_input_panel(frame, area)

    prefix_len = "ruby_coded> ".length
    assert_equal 0 + 1 + prefix_len + 5, frame.cursor_x
    assert_equal 21 + 1, frame.cursor_y
  end

  def test_render_input_panel_sets_cursor_at_beginning_when_empty
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 3, x: 0, y: 21)

    @host.render_input_panel(frame, area)

    prefix_len = "ruby_coded> ".length
    assert_equal 0 + 1 + prefix_len + 0, frame.cursor_x
    assert_equal 21 + 1, frame.cursor_y
  end

  def test_render_input_panel_cursor_reflects_mid_buffer_position
    @state.append_to_input("hello")
    @state.move_cursor_left
    @state.move_cursor_left
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 3, x: 0, y: 21)

    @host.render_input_panel(frame, area)

    prefix_len = "ruby_coded> ".length
    assert_equal 0 + 1 + prefix_len + 3, frame.cursor_x
  end

  def test_render_input_panel_no_cursor_during_streaming
    @state.streaming = true
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 3, x: 0, y: 21)

    @host.render_input_panel(frame, area)

    assert_nil frame.cursor_x
    assert_nil frame.cursor_y
  end

  def test_cover_banner_includes_version
    banner = @host.cover_banner
    assert_includes banner, RubyCoded::VERSION
    refute_includes banner, "%<version>s"
  end


  class ChatPanelHost
    include RubyCoded::Chat::Renderer::ChatPanelFormatting
    include RubyCoded::Chat::Renderer::ChatPanelSections
    include RubyCoded::Chat::Renderer::ChatPanel
    include RubyCoded::Chat::Renderer::ChatPanelInput
    include RubyCoded::Chat::Renderer::ChatPanelThinking

    def initialize(tui, state)
      @tui = tui
      @state = state
    end

    public :chat_panel_text, :render_chat_panel, :render_input_panel, :cover_banner
  end

  MockArea = Struct.new(:width, :height, :x, :y, keyword_init: true) do
    def initialize(width:, height:, x: 0, y: 0)
      super(width: width, height: height, x: x, y: y)
    end
  end

  class MockTui
    def paragraph(text:, block:, wrap: false, scroll: [0, 0])
      { type: :paragraph, text: text, block: block, wrap: wrap, scroll: scroll }
    end

    def block(title: nil, borders: [])
      { title: title, borders: borders }
    end

    def layout_split(area, direction:, constraints:) # rubocop:disable Lint/UnusedMethodArgument
      if constraints.first[:type] == :length
        top_height = [constraints.first[:value], area.height].min
        top = MockArea.new(width: area.width, height: top_height)
        bottom = MockArea.new(width: area.width, height: area.height - top_height)
        [top, bottom]
      else
        half = area.height / 2
        top = MockArea.new(width: area.width, height: half)
        bottom = MockArea.new(width: area.width, height: area.height - half)
        [top, bottom]
      end
    end

    def constraint_fill(weight)
      { type: :fill, weight: weight }
    end

    def constraint_length(len)
      { type: :length, value: len }
    end
  end

  class MockFrame
    attr_reader :rendered, :cursor_x, :cursor_y

    def initialize
      @rendered = []
      @cursor_x = nil
      @cursor_y = nil
    end

    def render_widget(widget, area)
      @rendered << [widget, area]
    end

    def set_cursor_position(x, y)
      @cursor_x = x
      @cursor_y = y
    end
  end
end
