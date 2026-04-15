# frozen_string_literal: true

require "yaml"
require "fileutils"

module RubyCode
  # This class is used to manage the users configurations for this gem
  class UserConfig
    CONFIG_DIR = File.join(Dir.home, ".ruby_code").freeze
    CONFIG_PATH = File.join(CONFIG_DIR, "config.yaml").freeze

    def initialize(config_path: CONFIG_PATH)
      @config_path = config_path
      @config_dir = File.dirname(@config_path)
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
      File.write(@config_path, full_config.to_yaml)
    end

    def save
      File.write(@config_path, full_config.to_yaml)
    end

    def directory_trusted?(dir = Dir.pwd)
      trusted = get_config("trusted_directories") || []
      trusted.include?(resolve_path(dir))
    end

    def trust_directory!(dir = Dir.pwd)
      trusted = get_config("trusted_directories") || []
      resolved = resolve_path(dir)
      return if trusted.include?(resolved)

      trusted << resolved
      set_config("trusted_directories", trusted)
    end

    private

    def find_or_create_config_file
      migrate_legacy_config
      FileUtils.mkdir_p(@config_dir)

      config = File.exist?(@config_path) ? YAML.load_file(@config_path) : nil

      if config.is_a?(Hash) && config["user_config"]
        config
      else
        default = user_config_info
        File.write(@config_path, default.to_yaml)
        default
      end
    end

    def migrate_legacy_config
      legacy_path = File.join(Dir.pwd, ".config.yaml")
      return unless File.exist?(legacy_path) && !File.exist?(@config_path)

      legacy_config = load_legacy_config(legacy_path)
      write_migrated_config(legacy_config, legacy_path)
    end

    def load_legacy_config(legacy_path)
      FileUtils.mkdir_p(@config_dir)
      config = YAML.load_file(legacy_path)
      normalize_legacy_permissions(config)
      config
    end

    def normalize_legacy_permissions(config)
      return unless config.is_a?(Hash) && config["user_config"]

      if config["user_config"]["current_directory_permission"]
        config["user_config"]["trusted_directories"] = [resolve_path(Dir.pwd)]
      end
      config["user_config"].delete("current_directory_permission")
    end

    def write_migrated_config(config, legacy_path)
      File.write(@config_path, config.to_yaml)
      File.delete(legacy_path)
    end

    def resolve_path(path)
      File.realpath(File.expand_path(path))
    rescue Errno::ENOENT
      File.expand_path(path)
    end

    def user_config_info
      {
        "user_config" => {
          "trusted_directories" => [],
          "model" => nil
        }
      }
    end
  end
end
