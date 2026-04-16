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

module RubyCoded
  module Chat
    # Main class for the AI chat interface
    class App
      include EventDispatch

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

      def handle_login_provider_selected
        selected = @state.login_selected_item
        return @state.exit_login_flow! unless selected

        provider_name = selected[:key]
        provider = Auth::AuthManager::PROVIDERS[provider_name]
        methods = provider.auth_methods

        if methods.size == 1
          @state.login_advance_to_api_key!(provider_name, methods.first[:key])
        else
          @state.login_advance_to_auth_method!(provider_name)
        end
      end

      def handle_login_method_selected
        selected = @state.login_selected_item
        return @state.exit_login_flow! unless selected

        case selected[:key]
        when :oauth   then start_oauth_flow
        when :api_key then @state.login_advance_to_api_key!(@state.login_provider, :api_key)
        end
      end

      def handle_login_key_submitted
        key = @state.login_key_buffer.strip
        provider = @state.login_provider_module

        unless provider.key_pattern.match?(key)
          @state.login_set_error!("Invalid API key format for #{provider.display_name}.")
          return
        end

        credentials = { "auth_method" => "api_key", "key" => key }
        @credentials_store.store(@state.login_provider, credentials)
        @auth_manager&.configure_ruby_llm!
        @state.exit_login_flow!
        @state.add_message(:system, "Logged in to #{provider.display_name} with API key.")
      rescue StandardError => e
        @state.login_set_error!("Login failed: #{e.message}")
      end

      def start_oauth_flow
        provider_name = @state.login_provider
        provider = Auth::AuthManager::PROVIDERS[provider_name]

        @oauth_pkce = Auth::PKCE.generate
        @oauth_state = SecureRandom.hex(16)
        @oauth_server = Auth::OAuthCallbackServer.new
        @oauth_server.start

        url = build_oauth_url(provider, @oauth_pkce[:challenge], @oauth_state)
        open_browser(url)

        @state.login_advance_to_oauth!(provider_name)

        @oauth_wait_thread = Thread.new do
          result = @oauth_server.wait_for_callback
          @state.login_set_oauth_result!(result)
        rescue StandardError => e
          @state.login_set_oauth_result!({ error: e.message })
        end
      end

      def poll_oauth_result
        result = @state.login_oauth_result
        return unless result

        @state.login_clear_oauth_result!
        process_oauth_result(result)
      end

      def process_oauth_result(result)
        provider_name = @state.login_provider
        provider = Auth::AuthManager::PROVIDERS[provider_name]

        if result[:error]
          @state.exit_login_flow!
          @state.add_message(:system, "OAuth failed: #{result[:error]}")
          return
        end

        if result[:state] != @oauth_state
          @state.exit_login_flow!
          @state.add_message(:system, "OAuth failed: state mismatch.")
          return
        end

        tokens = exchange_oauth_code(provider, result[:code], @oauth_pkce[:verifier])
        credentials = build_oauth_credentials(tokens)
        @credentials_store.store(provider_name, credentials)
        @auth_manager&.configure_ruby_llm!
        @state.exit_login_flow!
        @state.add_message(:system, "Logged in to #{provider.display_name} with OAuth.")
      rescue StandardError => e
        @state.exit_login_flow!
        @state.add_message(:system, "OAuth failed: #{e.message}")
      end

      def handle_login_oauth_cancel
        cleanup_oauth!
        @state.exit_login_flow!
        @state.add_message(:system, "Login cancelled.")
      end

      def handle_login_cancel
        cleanup_oauth! if @state.login_step == :oauth_waiting
        @state.exit_login_flow!
      end

      def cleanup_oauth!
        @oauth_server&.shutdown
        @oauth_wait_thread&.kill
        @oauth_server = nil
        @oauth_wait_thread = nil
        @oauth_pkce = nil
        @oauth_state = nil
      end

      def build_oauth_url(provider, challenge, state)
        params = URI.encode_www_form(
          client_id: provider.client_id,
          redirect_uri: provider.redirect_uri,
          response_type: "code",
          scope: provider.scopes,
          code_challenge: challenge,
          code_challenge_method: "S256",
          state: state
        )
        "#{provider.auth_url}?#{params}"
      end

      def exchange_oauth_code(provider, code, verifier)
        response = Faraday.post(provider.token_url, {
                                  "grant_type" => "authorization_code",
                                  "code" => code,
                                  "redirect_uri" => provider.redirect_uri,
                                  "client_id" => provider.client_id,
                                  "code_verifier" => verifier
                                })
        JSON.parse(response.body)
      end

      def build_oauth_credentials(tokens)
        {
          "auth_method" => "oauth",
          "access_token" => tokens["access_token"],
          "refresh_token" => tokens["refresh_token"],
          "expires_at" => (Time.now + tokens["expires_in"].to_i).iso8601
        }
      end

      def open_browser(url)
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then system("open", url)
        when /linux/ then system("xdg-open", url)
        when /mswin|mingw/ then system("start", url)
        end
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
