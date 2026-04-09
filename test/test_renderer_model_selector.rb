# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"
require "ruby_code/chat/renderer/model_selector"

class TestRendererModelSelector < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @tui = MockTui.new
    @host = ModelSelectorHost.new(@tui, @state)
  end

  def test_model_display_label_formats_id_and_provider
    model = FakeModel.new("gpt-4o-mini", "openai")
    label = @host.model_display_label(model)
    assert_equal "gpt-4o-mini (openai)", label
  end

  def test_model_display_label_marks_current_model
    model = FakeModel.new("gpt-4o", "openai")
    label = @host.model_display_label(model)
    assert_equal "gpt-4o (openai) *", label
  end

  def test_model_display_label_no_marker_for_other_model
    model = FakeModel.new("claude-sonnet-4-6", "anthropic")
    label = @host.model_display_label(model)
    assert_equal "claude-sonnet-4-6 (anthropic)", label
    refute_includes label, "*"
  end

  def test_model_display_label_handles_plain_string
    label = @host.model_display_label("some-model")
    assert_equal "some-model (unknown)", label
  end

  def test_centered_popup_returns_center_area
    area = :full_area
    result = @host.centered_popup(area)
    assert_equal :center, result
  end

  def test_popup_layout_splits_vertically
    result = @host.popup_layout(:popup_area)
    assert_equal %i[search_area list_area], result
  end

  def test_render_model_search_shows_filter_text
    @state.enter_model_select!([FakeModel.new("gpt-4o", "openai")])
    @state.append_to_model_filter("gpt")

    frame = MockFrame.new
    @host.render_model_search(frame, :search_area)

    widget, = frame.rendered.first
    assert_equal "Search: gpt", widget[:text]
  end

  def test_render_model_search_shows_empty_filter
    @state.enter_model_select!([])
    frame = MockFrame.new

    @host.render_model_search(frame, :search_area)

    widget, = frame.rendered.first
    assert_equal "Search: ", widget[:text]
  end

  def test_render_model_list_renders_model_labels
    models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("claude-sonnet-4-6", "anthropic")]
    @state.enter_model_select!(models)

    frame = MockFrame.new
    @host.render_model_list(frame, :list_area)

    widget, = frame.rendered.first
    assert_equal 2, widget[:items].size
    assert_equal "gpt-4o (openai) *", widget[:items][0]
    assert_equal "claude-sonnet-4-6 (anthropic)", widget[:items][1]
  end

  def test_render_model_list_respects_filter
    models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("claude-sonnet-4-6", "anthropic")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("claude")

    frame = MockFrame.new
    @host.render_model_list(frame, :list_area)

    widget, = frame.rendered.first
    assert_equal 1, widget[:items].size
    assert_includes widget[:items][0], "claude-sonnet-4-6"
  end

  def test_model_list_widget_includes_title_with_count
    widget = @host.model_list_widget(%w[a b c], 3)
    assert_equal "Models (3)", widget[:block][:title]
  end

  def test_model_list_widget_uses_selected_index_from_state
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)
    @state.model_select_down

    widget = @host.model_list_widget(%w[a b], 2)
    assert_equal 1, widget[:selected_index]
  end

  def test_render_model_selector_renders_three_widgets
    models = [FakeModel.new("gpt-4o", "openai")]
    @state.enter_model_select!(models)

    frame = MockFrame.new
    @host.render_model_selector(frame, :full_area)

    assert_equal 3, frame.rendered.size
  end


  FakeModel = Struct.new(:id, :provider)

  class ModelSelectorHost
    include RubyCode::Chat::Renderer::ModelSelector

    def initialize(tui, state)
      @tui = tui
      @state = state
    end

    public :render_model_selector, :popup_layout, :render_model_search,
           :render_model_list, :model_list_widget, :centered_popup, :model_display_label
  end

  class MockTui
    def paragraph(text:, block:)
      { type: :paragraph, text: text, block: block }
    end

    def list(items:, selected_index:, highlight_style:, highlight_symbol:, scroll_padding:, block:) # rubocop:disable Lint/UnusedMethodArgument
      { type: :list, items: items, selected_index: selected_index, block: block }
    end

    def block(title: nil, borders: [])
      { title: title, borders: borders }
    end

    def style(bg:, fg:, modifiers:)
      { bg: bg, fg: fg, modifiers: modifiers }
    end

    def clear
      :clear_widget
    end

    def layout_split(_area, direction:, constraints:) # rubocop:disable Lint/UnusedMethodArgument
      if constraints.size == 3
        %i[top center bottom]
      else
        %i[search_area list_area]
      end
    end

    def constraint_length(_n) = :length
    def constraint_fill(_n) = :fill
    def constraint_percentage(_n) = :percentage
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
