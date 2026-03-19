# frozen_string_literal: true

require "yaml"

require_relative "../config/user_config"

module RubyCode
  module Auth
    # This class is used to manage the credentials in the config file
    class CredentialsStore
      def initialize
        @config = UserConfig.new
      end

      def store(provider_name, credentials)
        cfg = @config.full_config
        cfg["providers"] ||= {}
        cfg["providers"][provider_name.to_s] = credentials
        @config.save
      end

      def retrieve(provider_name)
        @config.full_config.dig("providers", provider_name.to_s)
      end

      def remove(provider_name)
        providers = @config.full_config["providers"]
        return unless providers

        providers.delete(provider_name.to_s)
        @config.save
      end
    end
  end
end
