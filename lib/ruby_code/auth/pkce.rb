# frozen_string_literal: true

require "securerandom"
require "base64"
require "digest"

module RubyCode
  module Auth
    # Generates a Proof Key for Code Exchange
    # This will be used to authenticate the user with some AI providers
    module PKCE
      def self.generate
        verifier = SecureRandom.urlsafe_base64(32)
        challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
        { verifier: verifier, challenge: challenge }
      end
    end
  end
end
