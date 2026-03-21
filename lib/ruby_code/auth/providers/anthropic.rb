# frozen_string_literal: true

module RubyCode
  module Auth
    module Providers
      module Anthropic
        def self.display_name
          "Anthropic"
        end

        def self.auth_methods
          [
            { key: :api_key, label: "With your Anthropic API key (tokens consumption will be charged to your account)" }
          ]
        end

        def self.console_url
          "https://console.anthropic.com/settings/keys"
        end

        def self.key_pattern
          /\Ask-ant-/
        end

        def self.ruby_llm_key
          :anthropic_api_key
        end
      end
    end
  end
end
