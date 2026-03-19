# frozen_string_literal: true

require "tty-prompt"
require_relative "base"

module RubyCode
  module Strategies
    class APIKeyStrategy < Base
      def authenticate
        @prompt.say("Opening #{@provider.display_name} API key authentication in your browser...")
        open_browser(@provider.console_url)

        key = @prompt.ask("Please generate your API key and paste it here:")

        raise "No API key provided" if key.nil? || key.empty?
        raise "Invalid API key for #{@provider.display_name}" unless valid_format?(key)

        @prompt.say("API key validated successfully")

        { "auth_method" => "api_key", "key" => key }
      end

      def refresh(credentials)
        credentials
      end

      def validate(credentials)
        credentials["auth_method"] == "api_key" && valid_format?(credentials["key"])
      end

      private

      def valid_format?(key)
        @provider.key_pattern.match?(key)
      end
    end
  end
end
