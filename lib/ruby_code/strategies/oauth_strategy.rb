# frozen_string_literal: true

require_relative "base"
require_relative "../auth/pkce"
require_relative "../auth/oauth_callback_server"

module RubyCode
  module Strategies
    # OAuth strategy for authentication with OAuth providers (OPENAI)
    class OAuthStrategy < Base
      def authenticate
        pkce = PKCE.generate
        state = SecureRandom.hex(16)

        server = OAuthCallbackServer.new
        server.start

        url = build_auth_url(pkce[:challenge], state)
        puts "Please open the following URL in your browser to authenticate in #{@provider.display_name}..."
        open_browser(url)
        puts "Waiting authentication... (this may take a while)"

        result = server.wait_for_callback

        raise AuthError, result[:error] if result[:error]
        raise AuthError, "State mismatch" if result[:state] != state

        tokens = exchange_code(result[:code], pkce[:verifier])

        {
          type: "oauth",
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token],
          expires_at: (Time.now + tokens["expires_in"].to_i).iso8601
        }
      end

      def refresh(credentials)
        response = Faraday.post(@provider.token_url, {
                                  grant_type: "refresh_token",
                                  refresh_token: credentials[:refresh_token],
                                  client_id: @provider.client_id
                                })
        tokens = JSON.parse(response.body)

        {
          type: "oauth",
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token] || credentials[:refresh_token],
          expires_at: (Time.now + tokens["expires_in"].to_i).iso8601
        }
      end

      def validate(credentials)
        return false unless credentials&.dig("access_token")

        Time.parse(credentials["expires_at"]) > Time.now
      end

      private

      def build_auth_url(challenge, state)
        params = URI.encode_www_form(
          client_id: @provider.client_id,
          redirect_uri: @provider.redirect_uri,
          response_type: "code",
          scope: @provider.scopes,
          code_challenge: challenge,
          code_challenge_method: "S256",
          state: state
        )
        "#{@provider.auth_url}?#{params}"
      end

      def exchange_code(code, verifier)
        response = Faraday.post(@provider.token_url, {
                                  grant_type: "authorization_code",
                                  code: code,
                                  redirect_uri: @provider.redirect_uri,
                                  client_id: @provider.client_id,
                                  code_verifier: verifier
                                })
        JSON.parse(response.body)
      end
    end
  end
end
