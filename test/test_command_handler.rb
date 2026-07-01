# frozen_string_literal: true

require "test_helper"
require "ruby_coded/plugins"
require "ruby_coded/chat/command_handler"
require "ruby_coded/chat/state"
require "ruby_coded/auth/credentials_store"
require "ruby_coded/auth/auth_manager"
require "ruby_coded/commands/catalog"
require "ruby_coded/skills/catalog"

class TestCommandHandler < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, "config.yaml")

    @command_catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: RubyCoded.plugin_registry)
    @skill_catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)
    @state = RubyCoded::Chat::State.new(model: "gpt-4o", command_catalog: @command_catalog)
    @llm_bridge = MockLLMBridge.new
    @credentials_store = RubyCoded::Auth::CredentialsStore.new(config_path: @config_path)
    @user_config = RubyCoded::UserConfig.new(config_path: @config_path)
    @handler = RubyCoded::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      user_config: @user_config,
      credentials_store: @credentials_store,
      command_catalog: @command_catalog,
      skill_catalog: @skill_catalog
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

  def test_markdown_command_is_executed
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)
    File.write(
      File.join(commands_dir, "review_auth.md"),
      <<~MD
        ---
        command: /review-auth
        description: Review auth implementation
        usage: /review-auth [file]
        ---

        Review the authentication implementation and suggest improvements.
      MD
    )

    @command_catalog.reload!
    @handler = build_handler
    @handler.handle("/review-auth lib/auth.rb")

    assert_includes @llm_bridge.last_async_input, "Review the authentication implementation"
    assert_includes @llm_bridge.last_async_input, "Additional user input:"
    assert_includes @llm_bridge.last_async_input, "lib/auth.rb"
  end

  def test_commands_reload_loads_new_markdown_command
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)
    refute @command_catalog.find("/review-auth")

    File.write(
      File.join(commands_dir, "review_auth.md"),
      <<~MD
        ---
        command: /review-auth
        description: Review auth implementation
        ---

        Review the authentication implementation and suggest improvements.
      MD
    )

    @handler.handle("/commands reload")

    assert_equal "Commands reloaded. Added: 1, removed: 0, total custom commands: 1, invalid files ignored: 0, conflicts ignored: 0.",
                 @state.messages_snapshot.last[:content]
    assert @command_catalog.find("/review-auth")
  end

  def test_commands_reload_reports_invalid_and_removed_files
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)

    File.write(
      File.join(commands_dir, "review_auth.md"),
      <<~MD
        ---
        command: /review-auth
        description: Review auth implementation
        ---

        Review the authentication implementation and suggest improvements.
      MD
    )

    @handler.handle("/commands reload")
    File.delete(File.join(commands_dir, "review_auth.md"))
    File.write(File.join(commands_dir, "invalid.md"), "# invalid")

    @handler.handle("/commands reload")

    assert_equal "Commands reloaded. Added: 0, removed: 1, total custom commands: 0, invalid files ignored: 1, conflicts ignored: 0.\nInvalid files: invalid.md",
                 @state.messages_snapshot.last[:content]
  end

  def test_commands_reload_reports_conflicts
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)

    File.write(
      File.join(commands_dir, "help.md"),
      <<~MD
        ---
        command: /help
        description: Custom help
        ---

        This should conflict with the core help command.
      MD
    )

    @handler.handle("/commands reload")

    assert_equal "Commands reloaded. Added: 0, removed: 0, total custom commands: 0, invalid files ignored: 0, conflicts ignored: 1.\nConflicting commands: /help",
                 @state.messages_snapshot.last[:content]
  end

  def test_commands_list_shows_empty_state
    @handler.handle("/commands list")

    assert_equal "No custom commands loaded. Add markdown files under .ruby_coded/commands and run /commands reload.",
                 @state.messages_snapshot.last[:content]
  end

  def test_commands_list_shows_loaded_commands
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)

    File.write(
      File.join(commands_dir, "review_auth.md"),
      <<~MD
        ---
        command: /review-auth
        description: Review auth implementation
        usage: /review-auth [file]
        ---

        Review the authentication implementation and suggest improvements.
      MD
    )

    File.write(
      File.join(commands_dir, "summarize.md"),
      <<~MD
        ---
        command: /summarize
        description: Summarize the current context
        ---

        Summarize the current context.
      MD
    )

    @handler.handle("/commands reload")
    @handler.handle("/commands list")

    message = @state.messages_snapshot.last[:content]
    assert_includes message, "Custom commands:"
    assert_includes message, "/review-auth [file]"
    assert_includes message, "Review auth implementation"
    assert_includes message, "/summarize"
    assert_includes message, "Summarize the current context"
  end

  def test_commands_without_subcommand_show_usage
    @handler.handle("/commands")

    assert_equal "Usage: /commands [reload|list]", @state.messages_snapshot.last[:content]
  end

  def test_skills_list_shows_empty_state
    @handler.handle("/skills list")

    assert_equal "No project skills loaded. Add markdown files under .rubycoded/skills and run /skills reload.",
                 @state.messages_snapshot.last[:content]
  end

  def test_skills_reload_and_list_show_loaded_skills
    skills_dir = File.join(@tmpdir, ".rubycoded", "skills")
    FileUtils.mkdir_p(skills_dir)

    File.write(
      File.join(skills_dir, "rails.md"),
      <<~MD
        ---
        name: Rails Skill
        description: Help with Rails changes
        modes: [agent, plan]
        tags: [rails]
        ---

        Inspect related models and migrations first.
      MD
    )

    @handler.handle("/skills reload")
    assert_equal "Skills reloaded. Added: 1, removed: 0, total skills: 1, invalid files ignored: 0, duplicates ignored: 0.",
                 @state.messages_snapshot.last[:content]

    @handler.handle("/skills list")
    message = @state.messages_snapshot.last[:content]
    assert_includes message, "Project skills:"
    assert_includes message, "Rails Skill"
    assert_includes message, "Help with Rails changes"
    assert_includes message, "agent, plan"
  end

  def test_skills_reload_reports_invalid_and_duplicates
    skills_dir = File.join(@tmpdir, ".rubycoded", "skills")
    FileUtils.mkdir_p(skills_dir)

    File.write(
      File.join(skills_dir, "one.md"),
      <<~MD
        ---
        name: Duplicate Skill
        description: First
        modes: [chat]
        ---

        First body.
      MD
    )

    File.write(
      File.join(skills_dir, "two.md"),
      <<~MD
        ---
        name: Duplicate Skill
        description: Second
        modes: [chat]
        ---

        Second body.
      MD
    )

    File.write(File.join(skills_dir, "invalid.md"), "# invalid")

    @handler.handle("/skills reload")

    assert_equal "Skills reloaded. Added: 1, removed: 0, total skills: 1, invalid files ignored: 1, duplicates ignored: 1.\nInvalid files: invalid.md\nDuplicate skills: duplicate skill",
                 @state.messages_snapshot.last[:content]
  end

  def test_skills_without_subcommand_show_usage
    @handler.handle("/skills")

    assert_equal "Usage: /skills [reload|list]", @state.messages_snapshot.last[:content]
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
    handler_without_store = RubyCoded::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      user_config: @user_config,
      command_catalog: @command_catalog,
      skill_catalog: @skill_catalog
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
    RubyCoded::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      user_config: @user_config,
      credentials_store: RubyCoded::Auth::CredentialsStore.new(config_path: @config_path),
      command_catalog: @command_catalog,
      skill_catalog: @skill_catalog
    )
  end

  def store_credentials(provider_name, credentials)
    config = RubyCoded::UserConfig.new(config_path: @config_path)
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
    attr_reader :last_reset_model, :last_async_input

    def reset_chat!(model)
      @last_reset_model = model
    end

    def send_async(input)
      @last_async_input = input
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
