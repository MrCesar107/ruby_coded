# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"
require "ruby_code/chat/renderer/status_bar"

class TestRendererStatusBar < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @tui = MockTui.new
    @host = StatusBarHost.new(@tui, @state)
  end

  # --- render_status_bar ---

  def test_render_status_bar_shows_zero_tokens_initially
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 1)

    @host.render_status_bar(frame, area)

    assert_equal 1, frame.rendered.size
    widget, = frame.rendered.first
    assert_includes widget[:text], "↑0"
    assert_includes widget[:text], "↓0"
    assert_includes widget[:text], "(0 tokens)"
  end

  def test_render_status_bar_shows_model_name
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 1)

    @host.render_status_bar(frame, area)

    widget, = frame.rendered.first
    assert_includes widget[:text], "gpt-4o"
  end

  def test_render_status_bar_shows_cost_na_when_no_pricing
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 1)

    @host.render_status_bar(frame, area)

    widget, = frame.rendered.first
    assert_includes widget[:text], "Cost: N/A"
  end

  def test_render_status_bar_shows_token_counts_after_usage
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 150, output_tokens: 75)

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 1)

    @host.render_status_bar(frame, area)

    widget, = frame.rendered.first
    assert_includes widget[:text], "↑150"
    assert_includes widget[:text], "↓75"
    assert_includes widget[:text], "(225 tokens)"
  end

  def test_render_status_bar_shows_thinking_tokens_when_present
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, thinking_tokens: 500)

    frame = MockFrame.new
    area = MockArea.new(width: 120, height: 1)

    @host.render_status_bar(frame, area)

    widget, = frame.rendered.first
    assert_includes widget[:text], "💭500"
    assert_includes widget[:text], "(650 tokens)"
  end

  def test_render_status_bar_hides_thinking_when_zero
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 1)

    @host.render_status_bar(frame, area)

    widget, = frame.rendered.first
    refute_includes widget[:text], "💭"
  end

  def test_render_status_bar_formats_large_token_counts
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 1_234_567, output_tokens: 890_123)

    frame = MockFrame.new
    area = MockArea.new(width: 120, height: 1)

    @host.render_status_bar(frame, area)

    widget, = frame.rendered.first
    assert_includes widget[:text], "↑1,234,567"
    assert_includes widget[:text], "↓890,123"
    assert_includes widget[:text], "2,124,690 tokens"
  end

  def test_render_status_bar_renders_to_correct_area
    frame = MockFrame.new
    area = MockArea.new(width: 80, height: 1)

    @host.render_status_bar(frame, area)

    _, rendered_area = frame.rendered.first
    assert_equal area, rendered_area
  end

  # --- format_number ---

  def test_format_number_zero
    assert_equal "0", @host.format_number(0)
  end

  def test_format_number_small
    assert_equal "42", @host.format_number(42)
  end

  def test_format_number_hundreds
    assert_equal "999", @host.format_number(999)
  end

  def test_format_number_thousands
    assert_equal "1,000", @host.format_number(1000)
  end

  def test_format_number_large
    assert_equal "1,234,567", @host.format_number(1_234_567)
  end

  # --- format_cost ---

  def test_format_cost_nil
    assert_equal "Cost: N/A", @host.format_cost(nil)
  end

  def test_format_cost_tiny
    assert_equal "Cost: $0.00", @host.format_cost(0.000025)
  end

  def test_format_cost_small
    assert_equal "Cost: $0.05", @host.format_cost(0.05)
  end

  def test_format_cost_large
    assert_equal "Cost: $1.50", @host.format_cost(1.50)
  end

  def test_format_cost_zero
    assert_equal "Cost: $0.00", @host.format_cost(0.0)
  end

  def test_format_cost_boundary_below_one_cent
    assert_equal "Cost: $0.01", @host.format_cost(0.0099)
  end

  def test_format_cost_boundary_one_cent
    assert_equal "Cost: $0.01", @host.format_cost(0.01)
  end

  def test_format_cost_boundary_one_dollar
    assert_equal "Cost: $1.00", @host.format_cost(1.0)
  end

  # --- Host and Mocks ---

  class StatusBarHost
    include RubyCode::Chat::Renderer::StatusBar

    def initialize(tui, state)
      @tui = tui
      @state = state
    end

    public :render_status_bar, :format_number, :format_cost
  end

  MockArea = Struct.new(:width, :height, :x, :y, keyword_init: true) do
    def initialize(width:, height:, x: 0, y: 0)
      super(width: width, height: height, x: x, y: y)
    end
  end

  class MockTui
    def paragraph(text:, **_opts)
      { type: :paragraph, text: text }
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
