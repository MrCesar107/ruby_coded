# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestTokenCost < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "test-model")
  end

  def test_session_cost_breakdown_empty_when_no_usage
    breakdown = @state.session_cost_breakdown
    assert_empty breakdown
  end

  def test_session_cost_breakdown_returns_entry_per_model
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @state.instance_variable_set(:@model, "other-model")
    @state.add_message(:assistant, "World")
    @state.update_last_message_tokens(input_tokens: 200, output_tokens: 75)

    breakdown = @state.session_cost_breakdown
    models = breakdown.map { |e| e[:model] }
    assert_includes models, "test-model"
    assert_includes models, "other-model"
  end

  def test_session_cost_breakdown_accumulates_tokens_per_model
    @state.add_message(:assistant, "First")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)
    @state.add_message(:assistant, "Second")
    @state.update_last_message_tokens(input_tokens: 200, output_tokens: 75)

    breakdown = @state.session_cost_breakdown
    assert_equal 1, breakdown.size
    entry = breakdown.first
    assert_equal 300, entry[:input_tokens]
    assert_equal 125, entry[:output_tokens]
  end

  def test_session_cost_breakdown_nil_cost_for_unknown_model
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    breakdown = @state.session_cost_breakdown
    entry = breakdown.first
    assert_nil entry[:input_cost]
    assert_nil entry[:output_cost]
    assert_nil entry[:thinking_cost]
    assert_nil entry[:total_cost]
    assert_nil entry[:input_price_per_million]
    assert_nil entry[:output_price_per_million]
    assert_nil entry[:thinking_price_per_million]
  end

  def test_total_session_cost_nil_when_no_pricing
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    assert_nil @state.total_session_cost
  end

  def test_total_session_cost_nil_when_no_usage
    assert_nil @state.total_session_cost
  end

  def test_token_usage_by_model_tracks_across_model_switch
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    @state.instance_variable_set(:@model, "model-b")
    @state.add_message(:assistant, "B")
    @state.update_last_message_tokens(input_tokens: 200, output_tokens: 75)

    usage = @state.token_usage_by_model
    assert_equal 100, usage["test-model"][:input_tokens]
    assert_equal 50, usage["test-model"][:output_tokens]
    assert_equal 200, usage["model-b"][:input_tokens]
    assert_equal 75, usage["model-b"][:output_tokens]
  end

  def test_token_usage_by_model_returns_independent_copy
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)

    usage = @state.token_usage_by_model
    usage["test-model"][:input_tokens] = 999

    assert_equal 100, @state.token_usage_by_model["test-model"][:input_tokens]
  end

  def test_session_cost_breakdown_includes_thinking_tokens
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, thinking_tokens: 500)

    breakdown = @state.session_cost_breakdown
    entry = breakdown.first
    assert_equal 500, entry[:thinking_tokens]
  end

  def test_session_cost_breakdown_includes_cached_tokens
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, cached_tokens: 300)

    breakdown = @state.session_cost_breakdown
    entry = breakdown.first
    assert_equal 300, entry[:cached_tokens]
  end

  def test_session_cost_breakdown_includes_cache_creation_tokens
    @state.add_message(:assistant, "Hello")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50, cache_creation_tokens: 80)

    breakdown = @state.session_cost_breakdown
    entry = breakdown.first
    assert_equal 80, entry[:cache_creation_tokens]
  end

  def test_clear_messages_resets_token_usage
    @state.add_message(:assistant, "A")
    @state.update_last_message_tokens(input_tokens: 100, output_tokens: 50)
    @state.clear_messages!

    assert_empty @state.token_usage_by_model
    assert_empty @state.session_cost_breakdown
  end
end
