# frozen_string_literal: true

module RubyCode
  module Auth
    module Providers
      module OpenAI
        def self.display_name
          "OpenAI"
        end

        def self.client_id
          "app_EMoamEEZ73f0CkXaXp7hrann"
        end

        def self.auth_methods
          [
            { key: :oauth, label: "With your ChatGPT subscription (Go, Pro or Plus)" },
            { key: :api_key, label: "With your OpenAI API key (tokens consumption will be charged to your account)" }
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
          "http://localhost:18192/callback"
        end

        def self.scopes
          ""
        end

        def self.ruby_llm_key
          :openai_api_key
        end
      end
    end
  end
end
