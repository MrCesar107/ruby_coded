# frozen_string_literal: true

module RubyCoded
  module Chat
    class App
      # Manages the OAuth authorization flow: browser launch, callback server,
      # token exchange, and credential storage.
      module OAuthHandler
        private

        def start_oauth_flow
          provider_name = @state.login_provider
          provider = Auth::AuthManager::PROVIDERS[provider_name]
          @oauth_pkce = Auth::PKCE.generate
          @oauth_state = SecureRandom.hex(16)
          @oauth_server = Auth::OAuthCallbackServer.new
          @oauth_server.start
          open_browser(build_oauth_url(provider, @oauth_pkce[:challenge], @oauth_state))
          @state.login_advance_to_oauth!(provider_name)
          start_oauth_callback_thread!
        end

        def start_oauth_callback_thread!
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
          return fail_oauth!("OAuth failed: #{result[:error]}") if result[:error]
          return fail_oauth!("OAuth failed: state mismatch.") if result[:state] != @oauth_state

          complete_oauth_login(result)
        rescue StandardError => e
          fail_oauth!("OAuth failed: #{e.message}")
        end

        def fail_oauth!(message)
          @state.exit_login_flow!
          @state.add_message(:system, message)
        end

        def complete_oauth_login(result)
          provider_name = @state.login_provider
          provider = Auth::AuthManager::PROVIDERS[provider_name]
          tokens = exchange_oauth_code(provider, result[:code], @oauth_pkce[:verifier])
          @credentials_store.store(provider_name, build_oauth_credentials(tokens))
          @auth_manager&.configure_ruby_llm!
          recreate_bridge!
          @state.exit_login_flow!
          @state.add_message(:system, "Logged in to #{provider.display_name} with OAuth.")
        end

        def build_oauth_url(provider, challenge, state)
          params = {
            client_id: provider.client_id, redirect_uri: provider.redirect_uri,
            response_type: "code", scope: provider.scopes, code_challenge: challenge,
            code_challenge_method: "S256", state: state
          }
          params.merge!(provider.codex_auth_params) if provider.respond_to?(:codex_auth_params)
          "#{provider.auth_url}?#{URI.encode_www_form(params)}"
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
      end
    end
  end
end
