# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"
require "ruby_code/chat/command_handler/model_commands"

class TestModelCommands < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @llm_bridge = MockLLMBridge.new
    @user_config = MockUserConfig.new
    @host = ModelCommandsHost.new(@state, @llm_bridge, @user_config)
  end

  def test_model_id_returns_id_for_struct
    model = FakeModel.new("gpt-4o", "openai")
    assert_equal "gpt-4o", @host.model_id(model)
  end

  def test_model_id_returns_to_s_for_plain_object
    assert_equal "some-model", @host.model_id("some-model")
  end

  def test_model_match_returns_true_when_no_models
    @host.models = []
    assert @host.model_match?("anything")
  end

  def test_model_match_returns_true_when_model_found
    @host.models = [FakeModel.new("gpt-4o", "openai")]
    assert @host.model_match?("gpt-4o")
  end

  def test_model_match_returns_false_when_not_found
    @host.models = [FakeModel.new("gpt-4o", "openai")]
    refute @host.model_match?("gpt-5")
  end

  def test_model_match_adds_suggestion_message
    @host.models = [FakeModel.new("gpt-4o", "openai"), FakeModel.new("gpt-4o-mini", "openai")]
    @host.model_match?("gpt")

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "not found"
    assert_includes last_msg[:content], "Did you mean"
    assert_includes last_msg[:content], "gpt-4o"
  end

  def test_suggest_models_without_matches_shows_no_suggestions
    models = [FakeModel.new("gpt-4o", "openai")]
    @host.suggest_models("zzz", models)

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "not found"
    refute_includes last_msg[:content], "Did you mean"
  end

  def test_suggest_models_limits_to_five
    models = (1..10).map { |i| FakeModel.new("model-#{i}", "p") }
    @host.suggest_models("model", models)

    last_msg = @state.messages_snapshot.last
    suggestions = last_msg[:content].split("Did you mean: ").last
    assert_equal 5, suggestions.split(", ").size
  end

  def test_switch_to_model_updates_state
    @host.switch_to_model("new-model")

    assert_equal "new-model", @state.model
    assert_equal "new-model", @llm_bridge.last_reset_model
  end

  def test_switch_to_model_persists_config
    @host.switch_to_model("new-model")

    assert_equal %w[model new-model], @user_config.last_set
  end

  def test_switch_to_model_adds_confirmation_message
    @host.switch_to_model("new-model")

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Model switched to new-model"
  end

  def test_switch_to_model_works_without_user_config
    host = ModelCommandsHost.new(@state, @llm_bridge, nil)
    host.switch_to_model("new-model")

    assert_equal "new-model", @state.model
  end

  def test_open_model_selector_enters_select_mode
    @host.authenticated_models = [FakeModel.new("gpt-4o", "openai")]
    @host.open_model_selector

    assert @state.model_select?
    assert_equal 1, @state.model_list.size
  end

  def test_open_model_selector_shows_message_when_empty
    @host.authenticated_models = []
    @host.open_model_selector

    refute @state.model_select?
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "No available models found"
  end

  def test_cmd_model_without_args_opens_selector
    @host.authenticated_models = [FakeModel.new("gpt-4o", "openai")]
    @host.cmd_model(nil)

    assert @state.model_select?
  end

  def test_cmd_model_with_empty_args_opens_selector
    @host.authenticated_models = [FakeModel.new("gpt-4o", "openai")]
    @host.cmd_model("  ")

    assert @state.model_select?
  end

  def test_cmd_model_with_name_switches_model
    @host.models = [FakeModel.new("gpt-4o", "openai")]
    @host.cmd_model("gpt-4o")

    assert_equal "gpt-4o", @state.model
    assert_equal "gpt-4o", @llm_bridge.last_reset_model
  end

  def test_cmd_model_with_unknown_name_does_not_switch
    @host.models = [FakeModel.new("gpt-4o", "openai")]
    @host.cmd_model("unknown")

    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "not found"
  end


  FakeModel = Struct.new(:id, :provider)

  class MockLLMBridge
    attr_reader :last_reset_model

    def reset_chat!(model)
      @last_reset_model = model
    end
  end

  class MockUserConfig
    attr_reader :last_set

    def set_config(key, value)
      @last_set = [key, value]
    end
  end

  class ModelCommandsHost
    include RubyCode::Chat::CommandHandler::ModelCommands

    attr_accessor :models, :authenticated_models

    def initialize(state, llm_bridge, user_config)
      @state = state
      @llm_bridge = llm_bridge
      @user_config = user_config
      @models = []
      @authenticated_models = []
    end

    public :cmd_model, :model_match?, :suggest_models, :switch_to_model,
           :open_model_selector, :model_id

    private

    def fetch_chat_models
      @models
    end

    def fetch_models_for_authenticated_providers
      @authenticated_models
    end
  end
end
