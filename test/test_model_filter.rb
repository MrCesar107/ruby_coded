# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/model_filter"

class TestModelFilter < Minitest::Test
  FakeModel = Struct.new(:id, :provider, :created_at, :family)

  def test_excludes_gpt_35_turbo
    models = [
      FakeModel.new("gpt-3.5-turbo", "openai", recent_time, "gpt"),
      FakeModel.new("gpt-3.5-turbo-0125", "openai", recent_time, "gpt35_turbo"),
      FakeModel.new("gpt-4o", "openai", recent_time, "gpt")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["gpt-4o"], result.map(&:id)
  end

  def test_excludes_gpt4_date_snapshots
    models = [
      FakeModel.new("gpt-4-0613", "openai", recent_time, "other"),
      FakeModel.new("gpt-4-0314", "openai", recent_time, "other"),
      FakeModel.new("gpt-4o", "openai", recent_time, "gpt")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["gpt-4o"], result.map(&:id)
  end

  def test_excludes_gpt4_base
    models = [
      FakeModel.new("gpt-4", "openai", recent_time, "gpt"),
      FakeModel.new("gpt-4o", "openai", recent_time, "gpt")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["gpt-4o"], result.map(&:id)
  end

  def test_excludes_gpt4_turbo
    models = [
      FakeModel.new("gpt-4-turbo", "openai", recent_time, "gpt"),
      FakeModel.new("gpt-4-turbo-2024-04-09", "openai", recent_time, "gpt4_turbo"),
      FakeModel.new("gpt-4o", "openai", recent_time, "gpt")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["gpt-4o"], result.map(&:id)
  end

  def test_excludes_legacy_completions_models
    models = [
      FakeModel.new("text-davinci-003", "openai", recent_time, "other"),
      FakeModel.new("babbage-002", "openai", recent_time, "babbage"),
      FakeModel.new("curie-001", "openai", recent_time, "curie"),
      FakeModel.new("ada-002", "openai", recent_time, "ada"),
      FakeModel.new("davinci-002", "openai", recent_time, "davinci"),
      FakeModel.new("gpt-4o", "openai", recent_time, "gpt")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["gpt-4o"], result.map(&:id)
  end

  def test_excludes_deprecated_claude_models
    models = [
      FakeModel.new("claude-instant-v1", "anthropic", recent_time, "claude"),
      FakeModel.new("claude-2.1", "anthropic", recent_time, "claude"),
      FakeModel.new("claude-3-haiku-20240307", "anthropic", recent_time, "claude-haiku"),
      FakeModel.new("claude-sonnet-4-20250514", "anthropic", recent_time, "claude-sonnet")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["claude-sonnet-4-20250514"], result.map(&:id)
  end

  def test_excludes_deprecated_reasoning_models
    models = [
      FakeModel.new("o1-preview", "openai", recent_time, "o"),
      FakeModel.new("o1-mini", "openai", recent_time, "o-mini"),
      FakeModel.new("o3", "openai", recent_time, "o")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["o3"], result.map(&:id)
  end

  def test_does_not_exclude_gpt4o_variants
    models = [
      FakeModel.new("gpt-4o", "openai", recent_time, "gpt"),
      FakeModel.new("gpt-4o-mini", "openai", recent_time, "gpt-mini"),
      FakeModel.new("gpt-4o-2024-11-20", "openai", recent_time, "gpt")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)
    ids = result.map(&:id)

    assert_includes ids, "gpt-4o"
    assert_includes ids, "gpt-4o-mini"
  end

  def test_excludes_stale_models_by_created_at
    old_time = Time.now - (24 * 30 * 24 * 3600)
    models = [
      FakeModel.new("some-old-model", "openai", old_time, "other"),
      FakeModel.new("some-new-model", "openai", recent_time, "other")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["some-new-model"], result.map(&:id)
  end

  def test_preserves_models_without_created_at
    models = [
      FakeModel.new("azure-gpt-4o", "azure", nil, "gpt"),
      FakeModel.new("some-new-model", "openai", recent_time, "other")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)
    ids = result.map(&:id)

    assert_includes ids, "azure-gpt-4o"
    assert_includes ids, "some-new-model"
  end

  def test_preserves_latest_alias_even_if_old
    old_time = Time.now - (24 * 30 * 24 * 3600)
    models = [
      FakeModel.new("gemini-flash-latest", "gemini", old_time, "gemini-flash")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["gemini-flash-latest"], result.map(&:id)
  end

  def test_deduplicates_snapshot_when_latest_exists
    models = [
      FakeModel.new("claude-3-7-sonnet-latest", "anthropic", recent_time, "claude-sonnet"),
      FakeModel.new("claude-3-7-sonnet-20250219", "anthropic", recent_time, "claude-sonnet")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["claude-3-7-sonnet-latest"], result.map(&:id)
  end

  def test_keeps_snapshot_when_no_latest_exists
    models = [
      FakeModel.new("gpt-5-2025-08-07", "openai", recent_time, "gpt5"),
      FakeModel.new("gpt-5.1-2025-11-13", "openai", recent_time, "gpt5")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)
    ids = result.map(&:id)

    assert_includes ids, "gpt-5-2025-08-07"
    assert_includes ids, "gpt-5.1-2025-11-13"
  end

  def test_deduplication_is_scoped_by_provider
    models = [
      FakeModel.new("gemini-flash-latest", "gemini", recent_time, "gemini-flash"),
      FakeModel.new("gemini-2.0-flash-2025-01-01", "gemini", recent_time, "gemini-flash"),
      FakeModel.new("gemini-2.0-flash-2025-01-01", "vertexai", recent_time, "gemini-flash")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)
    ids = result.map(&:id)

    assert_includes ids, "gemini-flash-latest"
    refute_includes ids, "gemini-2.0-flash-2025-01-01" if result.find do |m|
      m.provider == "gemini" && m.id == "gemini-2.0-flash-2025-01-01"
    end
    assert(result.any? { |m| m.provider == "vertexai" && m.id == "gemini-2.0-flash-2025-01-01" })
  end

  def test_keeps_non_date_snapshot_ids_even_with_latest
    models = [
      FakeModel.new("codestral-latest", "mistral", recent_time, "devstral"),
      FakeModel.new("codestral-mamba", "mistral", recent_time, "devstral")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)
    ids = result.map(&:id)

    assert_includes ids, "codestral-latest"
    assert_includes ids, "codestral-mamba"
  end

  def test_filter_with_empty_list
    result = RubyCode::Chat::ModelFilter.filter([])

    assert_empty result
  end

  def test_filter_preserves_models_with_string_ids
    model = "some-model-string"

    result = RubyCode::Chat::ModelFilter.filter([model])

    assert_equal ["some-model-string"], result.map(&:to_s)
  end

  def test_ada_pattern_does_not_match_unrelated_names
    models = [
      FakeModel.new("ada-002", "openai", recent_time, "ada"),
      FakeModel.new("adaptive-model", "openai", recent_time, "other")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["adaptive-model"], result.map(&:id)
  end

  def test_age_cutoff_boundary
    just_within = Time.now - (18 * 30 * 24 * 3600) + 3600
    just_outside = Time.now - (18 * 30 * 24 * 3600) - 3600
    models = [
      FakeModel.new("model-within", "openai", just_within, "other"),
      FakeModel.new("model-outside", "openai", just_outside, "other")
    ]

    result = RubyCode::Chat::ModelFilter.filter(models)

    assert_equal ["model-within"], result.map(&:id)
  end

  private

  def recent_time
    Time.now - (30 * 24 * 3600)
  end
end
