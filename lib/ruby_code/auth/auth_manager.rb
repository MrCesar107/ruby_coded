# frozen_string_literal: true

require "yaml"
require "time"
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

      def initialize(config_path: UserConfig::CONFIG_PATH)
        @config_path = config_path
      end

      def login(provider_name)
        provider = PROVIDERS.fetch(provider_name)
        strategy = strategy_for(provider)
        credentials = strategy.authenticate
        credential_store.store(provider_name, credentials)
        configure_ruby_llm!
        print_api_credits_notice(provider)
        credentials
      end

      def logout(provider_name)
        credential_store.remove(provider_name)
        configure_ruby_llm!
      end

      def configured_providers
        PROVIDERS.keys
      end

      def authenticated_provider_names
        PROVIDERS.keys.select { |name| credential_store.retrieve(name) }
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
          config.max_retries = 1

          PROVIDERS.each do |name, provider|
            credentials = credential_store.retrieve(name)
            next unless credentials

            credentials = refresh_if_expired(name, provider, credentials)
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
        @credential_store ||= CredentialsStore.new(config_path: @config_path)
      end

      def extract_api_key(credentials)
        case credentials["auth_method"]
        when "oauth"   then credentials["access_token"]
        when "api_key" then credentials["key"]
        end
      end

      def refresh_if_expired(provider_name, provider, credentials)
        return credentials unless credentials["auth_method"] == "oauth"
        return credentials unless token_expired?(credentials)

        strategy = Strategies::OAuthStrategy.new(provider)
        refreshed = strategy.refresh(credentials)
        credential_store.store(provider_name, refreshed)
        refreshed
      rescue StandardError
        credentials
      end

      def token_expired?(credentials)
        expires_at = credentials["expires_at"]
        return false unless expires_at

        Time.parse(expires_at) <= Time.now + 60
      end

      def print_api_credits_notice(provider)
        console = provider.respond_to?(:console_url) ? provider.console_url : nil
        billing_hint = console ? " Check your balance at #{console}." : ""
        puts "\nNote: API usage consumes credits from your #{provider.display_name} account.#{billing_hint}\n\n"
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
