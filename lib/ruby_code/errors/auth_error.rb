# frozen_string_literal: true

module RubyCode
  module Errors
    # Authentication error
    class AuthError < StandardError
      def initialize(message = "Authentication failed")
        super(message)
      end
    end
  end
end
