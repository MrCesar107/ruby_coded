# frozen_string_literal: true

require "yaml"

require_relative "../config/user_config"

module RubyCode
  module Auth
    # This class is used to manage the credentials in the config file
    class CredentialsStore
      def initialize
        @user_cfg = UserConfig.new.find_or_create_config_file
      end

      def store(provider_name, credentials)
        @user_cfg["provider"] ||= {}
        @user_cfg["provider"][provider_name] = credentials
        File.write("./config.yaml", @user_cfg.to_yaml)
      end

      def retrieve(provider_name)
        @user_cfg["provider"][provider_name]
      end

      def remove(provider_name)
        @user_cfg["provider"].delete(provider_name)
        File.write("./config.yaml", @user_cfg.to_yaml)
      end
    end
  end
end
