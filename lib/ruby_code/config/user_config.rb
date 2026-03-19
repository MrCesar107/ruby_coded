# frozen_string_literal: true

require "yaml"

module RubyCode
  # This class is used to manage the users configurations for this gem
  class UserConfig
    def initialize
      @user_config = find_or_create_config_file
    end

    def full_config
      @user_config
    end

    def get_config(key)
      full_config["user_config"][key]
    end

    def set_config(key, value)
      full_config["user_config"][key] = value
      File.write(".config.yaml", full_config.to_yaml)
    end

    def save
      File.write(".config.yaml", full_config.to_yaml)
    end

    private

    def find_or_create_config_file
      config = File.exist?(".config.yaml") ? YAML.load_file(".config.yaml") : nil

      if config.is_a?(Hash) && config["user_config"]
        config
      else
        default = user_config_info
        File.write(".config.yaml", default.to_yaml)
        default
      end
    end

    def user_config_info
      {
        "user_config" => {
          "current_directory_permission" => false,
          "model" => nil
        }
      }
    end
  end
end
