# frozen_string_literal: true

require "base64"
require "json"

module RubyCoded
  module Auth
    # Decodes JWT tokens without external dependencies.
    # Used to extract the ChatGPT account ID from OAuth access tokens.
    module JWTDecoder
      JWT_CLAIM_PATH = "https://api.openai.com/auth"

      def self.decode(token)
        parts = token.to_s.split(".")
        return nil unless parts.size == 3

        padded = parts[1] + ("=" * ((4 - (parts[1].length % 4)) % 4))
        JSON.parse(Base64.urlsafe_decode64(padded))
      rescue StandardError
        nil
      end

      def self.extract_account_id(token)
        payload = decode(token)
        payload&.dig(JWT_CLAIM_PATH, "chatgpt_account_id")
      end
    end
  end
end
