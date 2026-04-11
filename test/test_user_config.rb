# frozen_string_literal: true

require "test_helper"
require "ruby_code/config/user_config"

class TestUserConfig < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = File.realpath(Dir.mktmpdir)
    @config_path = File.join(@tmpdir, "config.yaml")
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_creates_config_file_when_none_exists
    RubyCode::UserConfig.new(config_path: @config_path)
    assert File.exist?(@config_path)
  end

  def test_created_config_file_is_valid_yaml
    RubyCode::UserConfig.new(config_path: @config_path)
    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_instance_of Hash, raw
  end

  def test_default_trusted_directories_is_empty_array
    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_equal [], config.get_config("trusted_directories")
  end

  def test_default_model_is_nil
    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_nil config.get_config("model")
  end

  def test_get_config_returns_nil_for_unknown_key
    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_nil config.get_config("nonexistent_key")
  end

  def test_set_config_updates_value_in_memory
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.set_config("model", "gpt-4")
    assert_equal "gpt-4", config.get_config("model")
  end

  def test_set_config_persists_value_to_file
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.set_config("model", "gpt-4")

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_equal "gpt-4", raw["user_config"]["model"]
  end

  def test_set_config_with_string_value
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.set_config("model", "gpt-4")
    assert_equal "gpt-4", config.get_config("model")
  end

  def test_set_config_adds_new_key
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.set_config("custom_key", "custom_value")
    assert_equal "custom_value", config.get_config("custom_key")
  end

  def test_reads_existing_valid_config_file
    existing = {
      "user_config" => {
        "trusted_directories" => ["/some/path"],
        "model" => "gpt-4"
      }
    }
    File.write(@config_path, existing.to_yaml)

    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_equal ["/some/path"], config.get_config("trusted_directories")
    assert_equal "gpt-4", config.get_config("model")
  end

  def test_overwrites_config_file_without_user_config_key
    File.write(@config_path, "just a plain string")

    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_equal [], config.get_config("trusted_directories")
  end

  def test_overwrites_config_when_yaml_is_not_a_hash
    File.write(@config_path, [1, 2, 3].to_yaml)

    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_equal [], config.get_config("trusted_directories")
  end

  def test_multiple_set_config_calls_persist_all_values
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.set_config("trusted_directories", ["/trusted"])
    config.set_config("model", "claude")

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_equal ["/trusted"], raw["user_config"]["trusted_directories"]
    assert_equal "claude", raw["user_config"]["model"]
  end

  def test_full_config_returns_entire_hash
    config = RubyCode::UserConfig.new(config_path: @config_path)
    full = config.full_config

    assert_instance_of Hash, full
    assert full.key?("user_config")
  end

  def test_full_config_includes_user_config_values
    write_config(trusted_directories: ["/trusted"], model: "gpt-4")
    config = RubyCode::UserConfig.new(config_path: @config_path)

    assert_equal ["/trusted"], config.full_config["user_config"]["trusted_directories"]
    assert_equal "gpt-4", config.full_config["user_config"]["model"]
  end

  def test_full_config_preserves_extra_top_level_keys
    existing = {
      "user_config" => { "trusted_directories" => [], "model" => nil },
      "providers" => { "openai" => { "auth_method" => "api_key", "key" => "sk-test" } }
    }
    File.write(@config_path, existing.to_yaml)

    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert_equal "sk-test", config.full_config.dig("providers", "openai", "key")
  end

  def test_save_persists_full_config_to_file
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.full_config["providers"] = { "openai" => { "auth_method" => "api_key" } }
    config.save

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_equal "api_key", raw.dig("providers", "openai", "auth_method")
  end

  def test_save_preserves_user_config_values
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.set_config("trusted_directories", ["/trusted"])
    config.full_config["providers"] = { "openai" => {} }
    config.save

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_equal ["/trusted"], raw["user_config"]["trusted_directories"]
    assert raw.key?("providers")
  end

  # --- trusted directories ---

  def test_directory_trusted_returns_false_by_default
    config = RubyCode::UserConfig.new(config_path: @config_path)
    refute config.directory_trusted?("/some/random/dir")
  end

  def test_directory_trusted_returns_true_for_trusted_dir
    write_config(trusted_directories: [File.expand_path(@tmpdir)])
    config = RubyCode::UserConfig.new(config_path: @config_path)
    assert config.directory_trusted?(@tmpdir)
  end

  def test_trust_directory_adds_dir_to_list
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.trust_directory!(@tmpdir)

    assert config.directory_trusted?(@tmpdir)
  end

  def test_trust_directory_does_not_duplicate
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.trust_directory!(@tmpdir)
    config.trust_directory!(@tmpdir)

    assert_equal 1, config.get_config("trusted_directories").size
  end

  def test_trust_directory_persists_to_file
    config = RubyCode::UserConfig.new(config_path: @config_path)
    config.trust_directory!(@tmpdir)

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_includes raw["user_config"]["trusted_directories"], File.expand_path(@tmpdir)
  end

  # --- legacy migration ---

  def test_migrates_legacy_config_from_cwd
    original_dir = Dir.pwd
    legacy_dir = File.realpath(Dir.mktmpdir)

    begin
      legacy_content = {
        "user_config" => {
          "current_directory_permission" => true,
          "model" => "gpt-4"
        },
        "providers" => { "openai" => { "key" => "sk-test" } }
      }
      File.write(File.join(legacy_dir, ".config.yaml"), legacy_content.to_yaml)

      Dir.chdir(legacy_dir)
      config = RubyCode::UserConfig.new(config_path: @config_path)

      refute File.exist?(File.join(legacy_dir, ".config.yaml"))
      assert File.exist?(@config_path)

      assert_includes config.get_config("trusted_directories"), legacy_dir
      assert_equal "gpt-4", config.get_config("model")
      assert_equal "sk-test", config.full_config.dig("providers", "openai", "key")
    ensure
      Dir.chdir(original_dir)
      FileUtils.remove_entry(legacy_dir)
    end
  end

  def test_migration_skips_when_global_config_exists
    original_dir = Dir.pwd
    legacy_dir = File.realpath(Dir.mktmpdir)

    begin
      File.write(@config_path, { "user_config" => { "trusted_directories" => ["/existing"], "model" => nil } }.to_yaml)
      File.write(File.join(legacy_dir, ".config.yaml"), { "user_config" => { "current_directory_permission" => true, "model" => "old" } }.to_yaml)

      Dir.chdir(legacy_dir)
      config = RubyCode::UserConfig.new(config_path: @config_path)

      assert File.exist?(File.join(legacy_dir, ".config.yaml")), "Legacy file should NOT be deleted when global config already exists"
      assert_equal ["/existing"], config.get_config("trusted_directories")
    ensure
      Dir.chdir(original_dir)
      FileUtils.remove_entry(legacy_dir)
    end
  end

  def test_migration_handles_legacy_without_permission
    original_dir = Dir.pwd
    legacy_dir = File.realpath(Dir.mktmpdir)

    begin
      legacy_content = {
        "user_config" => {
          "current_directory_permission" => false,
          "model" => "claude"
        }
      }
      File.write(File.join(legacy_dir, ".config.yaml"), legacy_content.to_yaml)

      Dir.chdir(legacy_dir)
      config = RubyCode::UserConfig.new(config_path: @config_path)

      assert_equal [], config.get_config("trusted_directories") || []
      assert_equal "claude", config.get_config("model")
    ensure
      Dir.chdir(original_dir)
      FileUtils.remove_entry(legacy_dir)
    end
  end

  private

  def write_config(trusted_directories: [], model: nil)
    config = {
      "user_config" => {
        "trusted_directories" => trusted_directories,
        "model" => model
      }
    }
    File.write(@config_path, config.to_yaml)
  end
end
