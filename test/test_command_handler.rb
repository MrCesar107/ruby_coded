# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/command_handler"
require "ruby_code/chat/state"
require "ruby_code/auth/credentials_store"
require "ruby_code/auth/auth_manager"

class TestCommandHandler < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, "config.yaml")

    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @llm_bridge = MockLLMBridge.new
    @credentials_store = RubyCode::Auth::CredentialsStore.new(config_path: @config_path)
    @user_config = RubyCode::UserConfig.new(config_path: @config_path)
    @handler = RubyCode::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      user_config: @user_config,
      credentials_store: @credentials_store
    )
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_model_without_args_enters_model_select_mode
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    handler = build_handler

    fake_models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("gpt-4o-mini", "openai")]

    stub_models_by_provider(openai: fake_models) do
      handler.handle("/model")
    end

    assert @state.model_select?
    assert_equal 2, @state.model_list.size
    assert_equal 0, @state.model_select_index
  end

  def test_model_without_args_shows_message_when_no_models
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    handler = build_handler

    stub_models_by_provider(openai: []) do
      handler.handle("/model")
    end

    refute @state.model_select?
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "No available models found"
  end

  def test_model_with_name_switches_directly
    fake_models = [FakeModel.new("gpt-4o", "openai")]

    RubyLLM.stub(:models, FakeModelsRegistry.new(fake_models)) do
      @handler.handle("/model gpt-4o")
    end

    assert_equal "gpt-4o", @state.model
    assert_equal "gpt-4o", @llm_bridge.last_reset_model
    refute @state.model_select?
  end

  def test_model_with_unknown_name_suggests_alternatives
    fake_models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("gpt-4o-mini", "openai")]

    RubyLLM.stub(:models, FakeModelsRegistry.new(fake_models)) do
      @handler.handle("/model gpt-5")
    end

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "not found"
  end

  def test_model_select_filters_by_authenticated_providers_only
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    handler = build_handler

    openai_models = [FakeModel.new("gpt-4o", "openai")]
    anthropic_models = [FakeModel.new("claude-sonnet-4-6", "anthropic")]

    stub_models_by_provider(openai: openai_models, anthropic: anthropic_models) do
      handler.handle("/model")
    end

    assert @state.model_select?
    model_ids = @state.model_list.map(&:id)
    assert_includes model_ids, "gpt-4o"
    refute_includes model_ids, "claude-sonnet-4-6"
  end

  def test_model_select_includes_both_providers_when_both_authenticated
    store_credentials(:openai, { "auth_method" => "api_key", "key" => "sk-test" })
    store_credentials(:anthropic, { "auth_method" => "api_key", "key" => "sk-ant-test" })
    handler = build_handler

    openai_models = [FakeModel.new("gpt-4o", "openai")]
    anthropic_models = [FakeModel.new("claude-sonnet-4-6", "anthropic")]

    stub_models_by_provider(openai: openai_models, anthropic: anthropic_models) do
      handler.handle("/model")
    end

    assert @state.model_select?
    model_ids = @state.model_list.map(&:id)
    assert_includes model_ids, "gpt-4o"
    assert_includes model_ids, "claude-sonnet-4-6"
  end

  def test_help_command_shows_model_selector_description
    @handler.handle("/help")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Select a model from available providers"
  end

  def test_state_model_select_navigation
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p"), FakeModel.new("c", "p")]
    @state.enter_model_select!(models)

    assert_equal 0, @state.model_select_index

    @state.model_select_down
    assert_equal 1, @state.model_select_index

    @state.model_select_down
    assert_equal 2, @state.model_select_index

    @state.model_select_down
    assert_equal 0, @state.model_select_index

    @state.model_select_up
    assert_equal 2, @state.model_select_index
  end

  def test_state_selected_model_returns_current
    models = [FakeModel.new("a", "p"), FakeModel.new("b", "p")]
    @state.enter_model_select!(models)

    assert_equal "a", @state.selected_model.id

    @state.model_select_down
    assert_equal "b", @state.selected_model.id
  end

  def test_state_exit_model_select_resets_state
    models = [FakeModel.new("a", "p")]
    @state.enter_model_select!(models)
    assert @state.model_select?

    @state.exit_model_select!
    refute @state.model_select?
    assert_empty @state.model_list
    assert_equal 0, @state.model_select_index
    assert_equal "", @state.model_select_filter
  end

  def test_filter_narrows_model_list
    models = [
      FakeModel.new("gpt-4o", "openai"),
      FakeModel.new("gpt-4o-mini", "openai"),
      FakeModel.new("claude-sonnet-4-6", "anthropic")
    ]
    @state.enter_model_select!(models)

    assert_equal 3, @state.filtered_model_list.size

    @state.append_to_model_filter("gpt")
    assert_equal 2, @state.filtered_model_list.size
    assert_equal "gpt-4o", @state.filtered_model_list[0].id
    assert_equal "gpt-4o-mini", @state.filtered_model_list[1].id
  end

  def test_filter_by_provider_name
    models = [
      FakeModel.new("gpt-4o", "openai"),
      FakeModel.new("claude-sonnet-4-6", "anthropic")
    ]
    @state.enter_model_select!(models)

    @state.append_to_model_filter("anthropic")
    assert_equal 1, @state.filtered_model_list.size
    assert_equal "claude-sonnet-4-6", @state.filtered_model_list[0].id
  end

  def test_filter_is_case_insensitive
    models = [FakeModel.new("GPT-4o", "OpenAI")]
    @state.enter_model_select!(models)

    @state.append_to_model_filter("gpt")
    assert_equal 1, @state.filtered_model_list.size
  end

  def test_filter_resets_selection_index
    models = [
      FakeModel.new("gpt-4o", "openai"),
      FakeModel.new("gpt-4o-mini", "openai"),
      FakeModel.new("claude-sonnet-4-6", "anthropic")
    ]
    @state.enter_model_select!(models)

    @state.model_select_down
    @state.model_select_down
    assert_equal 2, @state.model_select_index

    @state.append_to_model_filter("c")
    assert_equal 0, @state.model_select_index
  end

  def test_backspace_widens_filter
    models = [
      FakeModel.new("gpt-4o", "openai"),
      FakeModel.new("claude-sonnet-4-6", "anthropic")
    ]
    @state.enter_model_select!(models)

    @state.append_to_model_filter("claude")
    assert_equal 1, @state.filtered_model_list.size

    @state.delete_last_filter_char
    assert_equal "claud", @state.model_select_filter
    assert_equal 1, @state.filtered_model_list.size

    4.times { @state.delete_last_filter_char }
    assert_equal "c", @state.model_select_filter

    @state.delete_last_filter_char
    assert_equal "", @state.model_select_filter
    assert_equal 2, @state.filtered_model_list.size
  end

  def test_selected_model_uses_filtered_list
    models = [
      FakeModel.new("gpt-4o", "openai"),
      FakeModel.new("claude-sonnet-4-6", "anthropic")
    ]
    @state.enter_model_select!(models)

    @state.append_to_model_filter("claude")
    assert_equal "claude-sonnet-4-6", @state.selected_model.id
  end

  def test_navigation_wraps_on_filtered_list
    models = [
      FakeModel.new("gpt-4o", "openai"),
      FakeModel.new("gpt-4o-mini", "openai"),
      FakeModel.new("claude-sonnet-4-6", "anthropic")
    ]
    @state.enter_model_select!(models)

    @state.append_to_model_filter("gpt")
    assert_equal 2, @state.filtered_model_list.size

    @state.model_select_down
    assert_equal 1, @state.model_select_index
    assert_equal "gpt-4o-mini", @state.selected_model.id

    @state.model_select_down
    assert_equal 0, @state.model_select_index
    assert_equal "gpt-4o", @state.selected_model.id
  end

  def test_enter_model_select_clears_previous_filter
    models = [FakeModel.new("gpt-4o", "openai")]
    @state.enter_model_select!(models)
    @state.append_to_model_filter("test")
    assert_equal "test", @state.model_select_filter

    @state.enter_model_select!(models)
    assert_equal "", @state.model_select_filter
  end

  def test_model_select_without_credentials_store_falls_back
    handler_without_store = RubyCode::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      user_config: @user_config
    )

    fake_models = [FakeModel.new("gpt-4o", "openai")]

    RubyLLM.stub(:models, FakeModelsRegistry.new(fake_models)) do
      handler_without_store.handle("/model")
    end

    assert @state.model_select?
    assert_equal 1, @state.model_list.size
  end

  FakeModel = Struct.new(:id, :provider)

  private

  def build_handler
    RubyCode::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      user_config: @user_config,
      credentials_store: RubyCode::Auth::CredentialsStore.new(config_path: @config_path)
    )
  end

  def store_credentials(provider_name, credentials)
    config = RubyCode::UserConfig.new(config_path: @config_path)
    cfg = config.full_config
    cfg["providers"] ||= {}
    cfg["providers"][provider_name.to_s] = credentials
    config.save
  end

  def stub_models_by_provider(providers_map, &)
    fake_registry = FakeModelsRegistryByProvider.new(providers_map)
    RubyLLM.stub(:models, fake_registry, &)
  end

  class MockLLMBridge
    attr_reader :last_reset_model

    def reset_chat!(model)
      @last_reset_model = model
    end
  end

  class FakeProviderModels
    def initialize(models)
      @models = models
    end

    def chat_models
      self
    end

    def to_a
      @models
    end
  end

  class FakeModelsRegistry
    def initialize(models)
      @models = models
    end

    def chat_models
      FakeProviderModels.new(@models)
    end

    def by_provider(_name)
      FakeProviderModels.new(@models)
    end
  end

  class FakeModelsRegistryByProvider
    def initialize(providers_map)
      @providers_map = providers_map
    end

    def by_provider(name)
      models = @providers_map[name] || []
      FakeProviderModels.new(models)
    end

    def chat_models
      all = @providers_map.values.flatten
      FakeProviderModels.new(all)
    end
  end
end
