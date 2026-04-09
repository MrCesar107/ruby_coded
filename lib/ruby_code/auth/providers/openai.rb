# frozen_string_literal: true

module RubyCode
  module Auth
    module Providers
      # OpenAI provider's configuration
      module OpenAI
        def self.display_name
          "OpenAI"
        end

        def self.client_id
          "app_EMoamEEZ73f0CkXaXp7hrann"
        end

        def self.auth_methods
          [
            { key: :oauth,
              label: "With your OpenAI account (requires API credits, " \
                     "your ChatGPT subscription does not cover API usage)" },
            { key: :api_key, label: "With an OpenAI API key (requires API credits at platform.openai.com)" }
          ]
        end

        def self.auth_url
          "https://auth.openai.com/oauth/authorize"
        end

        def self.token_url
          "https://auth.openai.com/oauth/token"
        end

        def self.console_url
          "https://platform.openai.com/account/api-keys"
        end

        def self.key_pattern
          /\Ask-/
        end

        def self.redirect_uri
          "http://localhost:1455/auth/callback"
        end

        def self.scopes
          "offline_access"
        end

        def self.ruby_llm_key
          :openai_api_key
        end
      end
    end
  end
end
