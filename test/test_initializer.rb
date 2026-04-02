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

  def test_prints_cover_banner
    write_config(current_directory_permission: true, with_provider: true)

    output = capture_io do
      stub_auth_manager do
        RubyCode::Initializer.new
      end
    end.first

    assert_includes output, "v#{RubyCode::VERSION}"
  end

  def test_does_not_ask_permission_when_already_granted
    write_config(current_directory_permission: true, with_provider: true)

    output = capture_io do
      stub_auth_manager do
        RubyCode::Initializer.new
      end
    end.first

    refute_includes output, "Do you trust this directory?"
  end

  def test_asks_for_permission_when_not_granted
    write_config(current_directory_permission: false, with_provider: true)

    mock_prompt = build_prompt_stub(yes_response: true)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_auth_manager do
        RubyCode::Initializer.new
      end
    end

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal true, raw["user_config"]["current_directory_permission"]
  end

  def test_saves_permission_false_when_user_declines
    write_config(current_directory_permission: false, with_provider: true)

    mock_prompt = build_prompt_stub(yes_response: false)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_auth_manager do
        capture_io { RubyCode::Initializer.new }
      end
    end

    raw = YAML.load_file(".config.yaml", permitted_classes: [Symbol])
    assert_equal false, raw["user_config"]["current_directory_permission"]
  end

  def test_creates_config_file_on_first_run
    mock_prompt = build_prompt_stub(yes_response: true)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_auth_manager do
        capture_io { RubyCode::Initializer.new }
      end
    end

    assert File.exist?(".config.yaml")
  end

  def test_calls_check_authentication
    write_config(current_directory_permission: true, with_provider: true)

    check_called = false
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { check_called = true }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { nil }

    RubyCode::Auth::AuthManager.stub(:new, auth_mock) do
      stub_chat_app do
        capture_io { RubyCode::Initializer.new }
      end
    end

    assert check_called
  end

  def test_calls_configure_ruby_llm
    write_config(current_directory_permission: true, with_provider: true)

    configure_called = false
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { nil }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { configure_called = true }

    RubyCode::Auth::AuthManager.stub(:new, auth_mock) do
      stub_chat_app do
        capture_io { RubyCode::Initializer.new }
      end
    end

    assert configure_called
  end

  private

  def write_config(current_directory_permission:, model: nil, with_provider: false)
    config = {
      "user_config" => {
        "current_directory_permission" => current_directory_permission,
        "model" => model
      }
    }
    if with_provider
      config["providers"] = { "openai" => { "auth_method" => "api_key", "key" => "sk-test" } }
    end
    File.write(".config.yaml", config.to_yaml)
  end

  def build_prompt_stub(yes_response: true)
    stub = Object.new
    stub.define_singleton_method(:yes?) { |*_args| yes_response }
    stub.define_singleton_method(:select) { |*_args, **_kwargs| :openai }
    stub
  end

  def stub_chat_app(&block)
    app_mock = Object.new
    app_mock.define_singleton_method(:run) { nil }

    RubyCode::Chat::App.stub(:new, app_mock, &block)
  end

  def stub_auth_manager(&block)
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { nil }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { nil }

    RubyCode::Auth::AuthManager.stub(:new, auth_mock) do
      stub_chat_app(&block)
    end
  end
end
