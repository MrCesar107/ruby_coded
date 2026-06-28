# frozen_string_literal: true

require "ratatui_ruby"
require "securerandom"
require "faraday"
require "json"
require "uri"

require_relative "state"
require_relative "input_handler"
require_relative "renderer"
require_relative "command_handler"
require_relative "llm_bridge"
require_relative "codex_bridge"
require_relative "codex_models"
require_relative "../commands/catalog"
require_relative "../auth/credentials_store"
require_relative "../auth/jwt_decoder"
require_relative "../auth/pkce"
require_relative "../auth/oauth_callback_server"
require_relative "app/event_dispatch"
require_relative "app/login_handler"
require_relative "app/oauth_handler"

module RubyCoded
  module Chat
    # Main class for the AI chat interface
    class App
      include EventDispatch
      include LoginHandler
      include OAuthHandler

      def initialize(model:, user_config: nil, auth_manager: nil, fallback_from_model: nil)
        @model = model
        @user_config = user_config
        @auth_manager = auth_manager
        @fallback_from_model = fallback_from_model
        apply_plugin_extensions!
        build_components!
        enable_default_agent_mode!
        announce_model_fallback
      end

      def build_components!
        @command_catalog = RubyCoded::Commands::Catalog.new(
          project_root: Dir.pwd,
          plugin_registry: RubyCoded.plugin_registry
        )

        @state = State.new(model: @model, command_catalog: @command_catalog)
        @credentials_store = Auth::CredentialsStore.new(user_config: @user_config)
        @llm_bridge = create_bridge
        @input_handler = InputHandler.new(@state)
        @command_handler = build_command_handler
      end

      IDLE_POLL_TIMEOUT = 0.016
      STREAMING_POLL_TIMEOUT = 0.05

      def run
        RatatuiRuby.run do |tui|
          init_tui(tui)
          run_event_loop
        end
      end

      private

      def init_tui(tui)
        @tui = tui
        @renderer = Renderer.new(tui, @state)
      end

      def run_event_loop
        loop do
          refresh_screen
          poll_oauth_result if @state.login_active? && @state.login_step == :oauth_waiting
          event = @tui.poll_event(timeout: poll_timeout)
          next if event.none?

          break if dispatch_event(event) == :quit
        end
      end

      def refresh_screen
        return unless @state.dirty?

        @renderer.draw
        @state.mark_clean!
      end

      def poll_timeout
        @state.streaming? ? STREAMING_POLL_TIMEOUT : IDLE_POLL_TIMEOUT
      end

      def apply_plugin_extensions!
        RubyCoded.plugin_registry.apply_extensions!(
          state_class: State,
          input_handler_class: InputHandler,
          renderer_class: Renderer,
          command_handler_class: CommandHandler
        )
      end

      def build_command_handler
        CommandHandler.new(
          @state,
          llm_bridge: @llm_bridge,
          user_config: @user_config,
          credentials_store: @credentials_store,
          auth_manager: @auth_manager,
          command_catalog: @command_catalog
        )
      end

      def announce_model_fallback
        return unless @fallback_from_model && !@fallback_from_model.to_s.strip.empty?
        return if @fallback_from_model == @model

        @state.add_message(
          :system,
          "Model #{@fallback_from_model} is not available (provider not authenticated). " \
          "Switched to #{@model}. Use /login to authenticate or /model to change."
        )
      end

      def enable_default_agent_mode!
        return if @llm_bridge.agentic_mode

        @llm_bridge.toggle_agentic_mode!(true)
      end

      def apply_selected_model
        selected = @state.selected_model
        return @state.exit_model_select! unless selected

        switch_model(selected)
      rescue StandardError => e
        @state.exit_model_select!
        @state.add_message(:system, "Failed to switch model: #{e.message}")
      end

      def switch_model(selected)
        model_name = selected.respond_to?(:id) ? selected.id : selected.to_s
        @state.model = model_name
        @llm_bridge.reset_chat!(model_name)
        @user_config&.set_config("model", model_name)
        @state.exit_model_select!
        @state.add_message(:system, "Model switched to #{model_name}.")
      end

      def create_bridge
        openai_creds = @credentials_store.retrieve(:openai)
        if openai_creds && openai_creds["auth_method"] == "oauth"
          @state.codex_mode = true
          ensure_valid_codex_model!
          CodexBridge.new(@state, credentials_store: @credentials_store, auth_manager: @auth_manager)
        else
          @state.codex_mode = false
          LLMBridge.new(@state)
        end
      end

      def ensure_valid_codex_model!
        return if CodexModels.codex_model?(@state.model)

        @state.model = CodexBridge::DEFAULT_MODEL
        @user_config&.set_config("model", CodexBridge::DEFAULT_MODEL)
      end

      def recreate_bridge!
        @command_catalog.reload!
        agentic = @llm_bridge.agentic_mode
        plan = @llm_bridge.plan_mode
        @llm_bridge = create_bridge
        @llm_bridge.toggle_agentic_mode!(agentic) if agentic
        @llm_bridge.toggle_plan_mode!(plan) if plan
        @command_handler = build_command_handler
      end
    end
  end
end
