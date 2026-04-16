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
require_relative "../auth/credentials_store"
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

      def initialize(model:, user_config: nil, auth_manager: nil)
        @model = model
        @user_config = user_config
        @auth_manager = auth_manager
        apply_plugin_extensions!
        @state = State.new(model: model)
        @llm_bridge = LLMBridge.new(@state)
        @input_handler = InputHandler.new(@state)
        @credentials_store = Auth::CredentialsStore.new
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
          auth_manager: @auth_manager
        )
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

    end
  end
end
