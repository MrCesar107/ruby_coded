# frozen_string_literal: true

require "test_helper"
require "ruby_code/plugins/base"
require "ruby_code/plugins/registry"

class TestPluginRegistry < Minitest::Test
  def setup
    @registry = RubyCode::Plugins::Registry.new
  end

  def test_starts_empty
    assert_empty @registry.plugins
  end

  def test_register_valid_plugin
    @registry.register(DummyPlugin)
    assert_includes @registry.plugins, DummyPlugin
  end

  def test_rejects_non_plugin_class
    assert_raises(ArgumentError) { @registry.register(String) }
  end

  def test_rejects_non_class
    assert_raises(ArgumentError) { @registry.register("not_a_class") }
  end

  def test_prevents_duplicate_registration
    @registry.register(DummyPlugin)
    @registry.register(DummyPlugin)
    assert_equal 1, @registry.plugins.size
  end

  def test_state_extensions
    @registry.register(DummyPlugin)
    @registry.register(EmptyPlugin)
    assert_equal [DummyStateModule], @registry.state_extensions
  end

  def test_input_extensions
    @registry.register(DummyPlugin)
    assert_equal [DummyInputModule], @registry.input_extensions
  end

  def test_renderer_extensions
    @registry.register(DummyPlugin)
    assert_equal [DummyRendererModule], @registry.renderer_extensions
  end

  def test_command_handler_extensions
    @registry.register(CommandPlugin)
    assert_equal [CommandHandlerModule], @registry.command_handler_extensions
  end

  def test_input_handler_configs
    @registry.register(DummyPlugin)
    configs = @registry.input_handler_configs
    assert_equal 1, configs.size
    assert_equal :handle_dummy_input, configs.first[:method]
  end

  def test_render_configs
    @registry.register(DummyPlugin)
    configs = @registry.render_configs
    assert_equal 1, configs.size
    assert_equal :render_dummy, configs.first[:method]
  end

  def test_all_commands_merges_from_plugins
    @registry.register(CommandPlugin)
    assert_equal({ "/deploy" => :cmd_deploy }, @registry.all_commands)
  end

  def test_all_command_descriptions
    @registry.register(CommandPlugin)
    assert_equal({ "/deploy" => "Deploy the app" }, @registry.all_command_descriptions)
  end

  def test_apply_extensions_includes_modules
    target = Class.new
    @registry.register(DummyPlugin)
    @registry.apply_extensions!(
      state_class: target,
      input_handler_class: target,
      renderer_class: target,
      command_handler_class: Class.new
    )
    assert_includes target.ancestors, DummyStateModule
    assert_includes target.ancestors, DummyInputModule
    assert_includes target.ancestors, DummyRendererModule
  end

  def test_apply_extensions_skips_already_included
    target = Class.new
    target.include(DummyStateModule)
    @registry.register(DummyPlugin)
    @registry.apply_extensions!(
      state_class: target,
      input_handler_class: Class.new,
      renderer_class: Class.new,
      command_handler_class: Class.new
    )
    count = target.ancestors.count(DummyStateModule)
    assert_equal 1, count
  end

  # --- Test fixtures ---

  module DummyStateModule; end
  module DummyInputModule; end
  module DummyRendererModule; end
  module CommandHandlerModule; end

  class DummyPlugin < RubyCode::Plugins::Base
    def self.plugin_name = :dummy
    def self.state_extension = DummyStateModule
    def self.input_extension = DummyInputModule
    def self.renderer_extension = DummyRendererModule
    def self.input_handler_method = :handle_dummy_input
    def self.render_method = :render_dummy
  end

  class EmptyPlugin < RubyCode::Plugins::Base
    def self.plugin_name = :empty
  end

  class CommandPlugin < RubyCode::Plugins::Base
    def self.plugin_name = :command_test
    def self.commands = { "/deploy" => :cmd_deploy }
    def self.command_descriptions = { "/deploy" => "Deploy the app" }
    def self.command_handler_extension = CommandHandlerModule
  end
end
