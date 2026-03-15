# frozen_string_literal: true

require "test_helper"
require "ruby_code/version"
require "ruby_code/initializer"

class TestInitializer < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_does_not_ask_permission_when_already_granted
    write_config(current_directory_permission: true)

    output = capture_io { RubyCode::Initializer.new }.first
    refute_includes output, "Do you trust this directory?"
  end

  def test_asks_for_permission_when_not_granted
    write_config(current_directory_permission: false)

    $stdin = StringIO.new("y\n")
    output = capture_io { RubyCode::Initializer.new }.first
    assert_includes output, "Do you trust this directory?"
  ensure
    $stdin = STDIN
  end

  def test_saves_permission_true_when_user_accepts
    write_config(current_directory_permission: false)

    $stdin = StringIO.new("y\n")
    capture_io { RubyCode::Initializer.new }

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal true, raw["current_directory_permission"]
  ensure
    $stdin = STDIN
  end

  def test_saves_permission_false_when_user_declines
    write_config(current_directory_permission: false)

    $stdin = StringIO.new("n\n")
    capture_io { RubyCode::Initializer.new }

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal false, raw["current_directory_permission"]
  ensure
    $stdin = STDIN
  end

  def test_creates_config_file_on_first_run
    $stdin = StringIO.new("y\n")
    capture_io { RubyCode::Initializer.new }

    assert File.exist?(".config.yaml")
  ensure
    $stdin = STDIN
  end

  def test_asks_permission_on_fresh_config
    $stdin = StringIO.new("n\n")
    output = capture_io { RubyCode::Initializer.new }.first

    assert_includes output, "Do you trust this directory?"
  ensure
    $stdin = STDIN
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
