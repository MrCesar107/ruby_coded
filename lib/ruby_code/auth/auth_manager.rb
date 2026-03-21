# frozen_string_literal: true

require "yaml"
require "ruby_llm"
require "tty-prompt"

require_relative "providers/openai"
require_relative "providers/anthropic"
require_relative "../strategies/oauth_strategy"
require_relative "../strategies/api_key_strategy"
require_relative "credentials_store"

module RubyCode
  module Auth
    # This class is used to manage the authentication process for the different
    # AI providers
    class AuthManager
      PROVIDERS = {
        openai: Providers::OpenAI,
        anthropic: Providers::Anthropic
      }.freeze

      def login(provider_name)
        provider = PROVIDERS.fetch(provider_name)
        strategy = strategy_for(provider)
        credentials = strategy.authenticate
        credential_store.store(provider_name, credentials)
        configure_ruby_llm!
        credentials
      end

      def logout(provider_name)
        credential_store.remove(provider_name)
        configure_ruby_llm!
      end

      def configured_providers
        PROVIDERS.keys
      end

      def check_authentication
        return if configured_providers.any? { |name| credential_store.retrieve(name) }

        provider_name = choose_provider
        login(provider_name)
      end

      def login_prompt
        provider_name = choose_provider
        login(provider_name)
      end

      def configure_ruby_llm!
        RubyLLM.configure do |config|
          PROVIDERS.each do |name, provider|
            credentials = credential_store.retrieve(name)
            next unless credentials

            key = extract_api_key(credentials)
            config.send("#{provider.ruby_llm_key}=", key)
          end
        end
      end

      private

      def prompt
        @prompt ||= TTY::Prompt.new
      end

      def choose_provider
        prompt.select("Please select the AI provider you want to log in:",
                      configured_providers,
                      per_page: 10)
      end

      def strategy_for(provider)
        method = choose_auth_method(provider)
        case method
        when :oauth   then Strategies::OAuthStrategy.new(provider)
        when :api_key then Strategies::APIKeyStrategy.new(provider)
        else
          raise "Invalid authentication method: #{method}"
        end
      end

      def credential_store
        @credential_store ||= CredentialsStore.new
      end

      def extract_api_key(credentials)
        case credentials["auth_method"]
        when "oauth"   then credentials["access_token"]
        when "api_key" then credentials["key"]
        end
      end

      def choose_auth_method(provider)
        methods = provider.auth_methods
        return methods.first[:key] if methods.size == 1

        choices = methods.map { |m| { name: m[:label], value: m[:key] } }
        prompt.select("How would you like to authenticate with #{provider.display_name}?", choices)
      end
    end
  end
end
