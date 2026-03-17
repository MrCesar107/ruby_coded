# frozen_string_literal: true

require "yaml"
require "ruby_llm"

require_relative "providers/openai"
require_relative "../strategies/oauth_strategy"
require_relative "credentials_store"

module RubyCode
  module Auth
    # This class is used to manage the authentication process for the different
    # AI providers
    class AuthManager
      PROVIDERS = { openai: Providers::OpenAI }.freeze

      def login(provider_name)
        provider = PROVIDERS.fetch(provider_name)
        strategy = strategy_for(provider)
        credentials = strategy.authenticate
        store_credentials(provider_name, credentials)
        configure_ruby_llm
        credentials
      end

      def logout(provider_name)
        credential_store.remove(provider_name)
        configure_ruby_llm
      end

      def configured_providers
        PROVIDERS.keys
      end

      private

      def configure_ruby_llm
        # Reads stored credentials and configures RubyLLM
        RubyLLM.configure do |config|
          PROVIDERS.each do |name, provider|
            credentials = credential_store.retrieve(name)
            next unless credentials

            key = extract_api_key(credentials)
            config.send("#{provider.ruby_llm_key}=", key)
          end
        end
      end

      def strategy_for(provider)
        case provider.strategy
        when :oauth then OAuthStrategy.new(provider)
        end
      end

      def store_credentials(provider_name, credentials)
        CredentialsStore.new.store(provider_name, credentials)
      end
    end
  end
end
