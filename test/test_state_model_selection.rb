# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestStateModelSelection < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
  end

  def test_model_select_is_false_by_default
    refute @state.model_select?
  end

  def test_enter_model_select_activates_mode
    @state.enter_model_select!([FakeModel.new("a", "p")])
    assert @state.model_select?
  end

  def test_enter_model_select_sets_models
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)
    assert_equal 2, @state.model_list.size
  end

  def test_enter_model_select_resets_index_and_filter
    @state.enter_model_select!([FakeModel.new("a", "p")])
    @state.append_to_model_filter("test")
    @state.model_select_down

    @state.enter_model_select!([FakeModel.new("b", "p")])
    assert_equal 0, @state.model_select_index
    assert_equal "", @state.model_select_filter
  end

  def test_exit_model_select_resets_state
    @state.enter_model_select!([FakeModel.new("a", "p")])
    @state.exit_model_select!

    refute @state.model_select?
    assert_empty @state.model_list
    assert_equal 0, @state.model_select_index
    assert_equal "", @state.model_select_filter
  end

  def test_model_select_down_wraps_around
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p"), FakeModel.new("c", "p")]
    @state.enter_model_select!(models)

    @state.model_select_down
    assert_equal 1, @state.model_select_index
    @state.model_select_down
    assert_equal 2, @state.model_select_index
    @state.model_select_down
    assert_equal 0, @state.model_select_index
  end

  def test_model_select_up_wraps_around
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)

    @state.model_select_up
    assert_equal 1, @state.model_select_index
  end

  def test_model_select_up_noop_when_empty
    @state.enter_model_select!([])
    @state.model_select_up
    assert_equal 0, @state.model_select_index
  end

  def test_model_select_down_noop_when_empty
    @state.enter_model_select!([])
    @state.model_select_down
    assert_equal 0, @state.model_select_index
  end

  def test_selected_model_returns_current
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)

    assert_equal "a", @state.selected_model.id
    @state.model_select_down
    assert_equal "b", @state.selected_model.id
  end

  def test_filtered_model_list_returns_all_without_filter
    models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("claude", "anthropic")]
    @state.enter_model_select!(models)

    assert_equal 2, @state.filtered_model_list.size
  end

  def test_filtered_model_list_filters_by_id
    models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("claude", "anthropic")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("gpt")

    assert_equal 1, @state.filtered_model_list.size
    assert_equal "gpt-4o", @state.filtered_model_list.first.id
  end

  def test_filtered_model_list_filters_by_provider
    models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("claude", "anthropic")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("anthropic")

    assert_equal 1, @state.filtered_model_list.size
    assert_equal "claude", @state.filtered_model_list.first.id
  end

  def test_filtered_model_list_is_case_insensitive
    models = [FakeModel.new("GPT-4o", "OpenAI")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("gpt")

    assert_equal 1, @state.filtered_model_list.size
  end

  def test_append_to_model_filter_resets_index
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)
    @state.model_select_down
    assert_equal 1, @state.model_select_index

    @state.append_to_model_filter("x")
    assert_equal 0, @state.model_select_index
  end

  def test_delete_last_filter_char_removes_character
    @state.enter_model_select!([FakeModel.new("a", "p")])
    @state.append_to_model_filter("abc")
    @state.delete_last_filter_char

    assert_equal "ab", @state.model_select_filter
  end

  def test_delete_last_filter_char_resets_index
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("a")
    @state.model_select_down

    @state.delete_last_filter_char
    assert_equal 0, @state.model_select_index
  end

  def test_selected_model_uses_filtered_list
    models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("claude", "anthropic")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("claude")

    assert_equal "claude", @state.selected_model.id
  end


  FakeModel = Struct.new(:id, :provider)
end
