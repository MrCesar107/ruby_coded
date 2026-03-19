# frozen_string_literal: true

require "test_helper"
require "ruby_code/config/user_config"

class TestUserConfig < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_creates_config_file_when_none_exists
    RubyCode::UserConfig.new
    assert File.exist?(".config.yaml")
  end

  def test_created_config_file_is_valid_yaml
    RubyCode::UserConfig.new
    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_instance_of Hash, raw
  end

  def test_default_current_directory_permission_is_false
    config = RubyCode::UserConfig.new
    assert_equal false, config.get_config("current_directory_permission")
  end

  def test_default_model_is_nil
    config = RubyCode::UserConfig.new
    assert_nil config.get_config("model")
  end

  def test_get_config_returns_nil_for_unknown_key
    config = RubyCode::UserConfig.new
    assert_nil config.get_config("nonexistent_key")
  end

  def test_sat_config_updates_value_in_memory
    config = RubyCode::UserConfig.new
    config.set_config("current_directory_permission", true)
    assert_equal true, config.get_config("current_directory_permission")
  end

  def test_sat_config_persists_value_to_file
    config = RubyCode::UserConfig.new
    config.set_config("current_directory_permission", true)

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal true, raw["user_config"]["current_directory_permission"]
  end

  def test_sat_config_with_string_value
    config = RubyCode::UserConfig.new
    config.set_config("model", "gpt-4")
    assert_equal "gpt-4", config.get_config("model")
  end

  def test_sat_config_adds_new_key
    config = RubyCode::UserConfig.new
    config.set_config("custom_key", "custom_value")
    assert_equal "custom_value", config.get_config("custom_key")
  end

  def test_reads_existing_valid_config_file
    existing = {
      "user_config" => {
        "current_directory_permission" => true,
        "model" => "gpt-4"
      }
    }
    File.write(".config.yaml", existing.to_yaml)

    config = RubyCode::UserConfig.new
    assert_equal true, config.get_config("current_directory_permission")
    assert_equal "gpt-4", config.get_config("model")
  end

  def test_overwrites_config_file_without_user_config_key
    File.write(".config.yaml", "just a plain string")

    config = RubyCode::UserConfig.new
    assert_equal false, config.get_config("current_directory_permission")
  end

  def test_overwrites_config_when_yaml_is_not_a_hash
    File.write(".config.yaml", [1, 2, 3].to_yaml)

    config = RubyCode::UserConfig.new
    assert_equal false, config.get_config("current_directory_permission")
  end

  def test_multiple_sat_config_calls_persist_all_values
    config = RubyCode::UserConfig.new
    config.set_config("current_directory_permission", true)
    config.set_config("model", "claude")

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal true, raw["user_config"]["current_directory_permission"]
    assert_equal "claude", raw["user_config"]["model"]
  end

  def test_full_config_returns_entire_hash
    config = RubyCode::UserConfig.new
    full = config.full_config

    assert_instance_of Hash, full
    assert full.key?("user_config")
  end

  def test_full_config_includes_user_config_values
    write_config(current_directory_permission: true, model: "gpt-4")
    config = RubyCode::UserConfig.new

    assert_equal true, config.full_config["user_config"]["current_directory_permission"]
    assert_equal "gpt-4", config.full_config["user_config"]["model"]
  end

  def test_full_config_preserves_extra_top_level_keys
    existing = {
      "user_config" => { "current_directory_permission" => false, "model" => nil },
      "providers" => { "openai" => { "auth_method" => "api_key", "key" => "sk-test" } }
    }
    File.write(".config.yaml", existing.to_yaml)

    config = RubyCode::UserConfig.new
    assert_equal "sk-test", config.full_config.dig("providers", "openai", "key")
  end

  def test_save_persists_full_config_to_file
    config = RubyCode::UserConfig.new
    config.full_config["providers"] = { "openai" => { "auth_method" => "api_key" } }
    config.save

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal "api_key", raw.dig("providers", "openai", "auth_method")
  end

  def test_save_preserves_user_config_values
    config = RubyCode::UserConfig.new
    config.set_config("current_directory_permission", true)
    config.full_config["providers"] = { "openai" => {} }
    config.save

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal true, raw["user_config"]["current_directory_permission"]
    assert raw.key?("providers")
  end

  private

  def write_config(current_directory_permission:, model: nil)
    config = {
      "user_config" => {
        "current_directory_permission" => current_directory_permission,
        "model" => model
      }
    }
    File.write(".config.yaml", config.to_yaml)
  end
end
