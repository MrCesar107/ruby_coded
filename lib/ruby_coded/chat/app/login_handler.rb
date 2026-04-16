# frozen_string_literal: true

module RubyCoded
  module Chat
    class App
      # Handles login step navigation: provider selection, auth method selection,
      # API key submission, and login cancellation.
      module LoginHandler
        private

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
          save_api_key_credentials(key, provider)
        rescue StandardError => e
          @state.login_set_error!("Login failed: #{e.message}")
        end

        def save_api_key_credentials(key, provider)
          credentials = { "auth_method" => "api_key", "key" => key }
          @credentials_store.store(@state.login_provider, credentials)
          @auth_manager&.configure_ruby_llm!
          @state.exit_login_flow!
          @state.add_message(:system, "Logged in to #{provider.display_name} with API key.")
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
      end
    end
  end
end
