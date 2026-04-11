# frozen_string_literal: true

require "test_helper"
require "ruby_code/version"
require "ruby_code/initializer"

class TestInitializer < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, "config.yaml")
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_does_not_ask_permission_when_already_granted
    write_config(trusted_directories: [File.expand_path(@tmpdir)], with_provider: true)

    output = capture_io do
      stub_user_config do
        stub_auth_manager do
          RubyCode::Initializer.new
        end
      end
    end.first

    refute_includes output, "Do you trust this directory?"
  end

  def test_asks_for_permission_when_not_granted
    write_config(trusted_directories: [], with_provider: true)

    mock_prompt = build_prompt_stub(yes_response: true)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_user_config do
        stub_auth_manager do
          RubyCode::Initializer.new
        end
      end
    end

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_includes raw["user_config"]["trusted_directories"], File.expand_path(@tmpdir)
  end

  def test_exits_when_user_declines_permission
    write_config(trusted_directories: [], with_provider: true)

    mock_prompt = build_prompt_stub(yes_response: false)

    assert_raises(SystemExit) do
      TTY::Prompt.stub(:new, mock_prompt) do
        stub_user_config do
          stub_auth_manager do
            capture_io { RubyCode::Initializer.new }
          end
        end
      end
    end
  end

  def test_creates_config_file_on_first_run
    mock_prompt = build_prompt_stub(yes_response: true)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_user_config do
        stub_auth_manager do
          capture_io { RubyCode::Initializer.new }
        end
      end
    end

    assert File.exist?(@config_path)
  end

  def test_calls_check_authentication
    write_config(trusted_directories: [File.expand_path(@tmpdir)], with_provider: true)

    check_called = false
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { check_called = true }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { nil }

    RubyCode::Auth::AuthManager.stub(:new, auth_mock) do
      stub_user_config do
        stub_chat_app do
          capture_io { RubyCode::Initializer.new }
        end
      end
    end

    assert check_called
  end

  def test_calls_configure_ruby_llm
    write_config(trusted_directories: [File.expand_path(@tmpdir)], with_provider: true)

    configure_called = false
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { nil }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { configure_called = true }

    RubyCode::Auth::AuthManager.stub(:new, auth_mock) do
      stub_user_config do
        stub_chat_app do
          capture_io { RubyCode::Initializer.new }
        end
      end
    end

    assert configure_called
  end

  private

  def write_config(trusted_directories: [], model: nil, with_provider: false)
    config = {
      "user_config" => {
        "trusted_directories" => trusted_directories,
        "model" => model
      }
    }
    config["providers"] = { "openai" => { "auth_method" => "api_key", "key" => "sk-test" } } if with_provider
    File.write(@config_path, config.to_yaml)
  end

  def build_prompt_stub(yes_response: true)
    stub = Object.new
    stub.define_singleton_method(:yes?) { |*_args| yes_response }
    stub.define_singleton_method(:select) { |*_args, **_kwargs| :openai }
    stub
  end

  def stub_user_config(&block)
    config_path = @config_path
    RubyCode::UserConfig.stub(:new, ->(*_args, **_kwargs) { RubyCode::UserConfig.allocate.tap { |c| c.send(:initialize, config_path: config_path) } }, &block)
  end

  def stub_chat_app(&)
    app_mock = Object.new
    app_mock.define_singleton_method(:run) { nil }

    RubyCode::Chat::App.stub(:new, app_mock, &)
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
