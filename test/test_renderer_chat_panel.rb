# frozen_string_literal: true

require "test_helper"
require "ruby_code/version"
require "ruby_code/chat/state"
require "ruby_code/chat/renderer/chat_panel"

class TestRendererChatPanel < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @tui = MockTui.new
    @host = ChatPanelHost.new(@tui, @state)
  end

  def test_chat_panel_text_returns_banner_when_no_messages
    text = @host.chat_panel_text
    assert_includes text, "v#{RubyCode::VERSION}"
  end

  def test_chat_panel_text_formats_messages
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi there")

    text = @host.chat_panel_text
    assert_includes text, "> Hello"
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

    widget, = frame.rendered.first
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

    widget, = frame.rendered.first
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
    assert_includes chat_widget[:text], "> Explain ruby"
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
    assert_includes chat_widget[:text], "> Hello"
    assert_includes chat_widget[:text], "Hi!"
    assert_includes chat_widget[:text], "> Fix the bug"
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
    assert_includes widget[:text], "> Fix the bug"
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
    assert_includes text, "> Fix it"
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
    area = :input_area

    @host.render_input_panel(frame, area)

    widget, = frame.rendered.first
    assert_equal "ruby_code> hello world", widget[:text]
  end

  def test_render_input_panel_shows_empty_prompt
    frame = MockFrame.new

    @host.render_input_panel(frame, :input_area)

    widget, = frame.rendered.first
    assert_equal "ruby_code> ", widget[:text]
  end

  def test_cover_banner_includes_version
    banner = @host.cover_banner
    assert_includes banner, RubyCode::VERSION
    refute_includes banner, "%<version>s"
  end


  class ChatPanelHost
    include RubyCode::Chat::Renderer::ChatPanel

    def initialize(tui, state)
      @tui = tui
      @state = state
    end

    public :chat_panel_text, :render_chat_panel, :render_input_panel, :cover_banner
  end

  MockArea = Struct.new(:width, :height)

  class MockTui
    def paragraph(text:, block:, wrap: false, scroll: [0, 0])
      { type: :paragraph, text: text, block: block, wrap: wrap, scroll: scroll }
    end

    def block(title: nil, borders: [])
      { title: title, borders: borders }
    end

    def layout_split(area, direction:, constraints:) # rubocop:disable Lint/UnusedMethodArgument
      half = area.height / 2
      top = MockArea.new(width: area.width, height: half)
      bottom = MockArea.new(width: area.width, height: area.height - half)
      [top, bottom]
    end

    def constraint_fill(weight)
      { type: :fill, weight: weight }
    end

    def constraint_length(len)
      { type: :length, value: len }
    end
  end

  class MockFrame
    attr_reader :rendered

    def initialize
      @rendered = []
    end

    def render_widget(widget, area)
      @rendered << [widget, area]
    end
  end
end
