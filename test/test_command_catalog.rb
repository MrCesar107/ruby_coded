# frozen_string_literal: true

require "test_helper"
require "ruby_coded/commands/catalog"
require "ruby_coded/plugins/base"
require "ruby_coded/plugins/registry"

class TestCommandCatalog < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @registry = RubyCoded::Plugins::Registry.new
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_includes_core_commands
    catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: @registry)

    assert_equal :cmd_help, catalog.command_map["/help"]
    assert_equal "Show help message", catalog.command_descriptions["/help"]
    assert_equal :cmd_commands, catalog.command_map["/commands"]
    assert_equal "Manage custom markdown commands", catalog.command_descriptions["/commands"]
    assert_equal :cmd_skills, catalog.command_map["/skills"]
    assert_equal "Manage project-local skills", catalog.command_descriptions["/skills"]
  end

  def test_includes_plugin_commands
    @registry.register(CommandPlugin)
    catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: @registry)

    assert_equal :cmd_deploy, catalog.command_map["/deploy"]
    assert_equal "Deploy the app", catalog.command_descriptions["/deploy"]
  end

  def test_includes_markdown_commands_when_no_conflict
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)
    File.write(File.join(commands_dir, "review.md"), <<~MD)
      ---
      command: /review
      description: Review the code
      ---

      Review the code and suggest improvements.
    MD

    catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: @registry)

    assert_equal "Review the code", catalog.command_descriptions["/review"]
    assert catalog.find("/review").markdown?
    assert_equal 1, catalog.definitions_for_source(:markdown).size
  end

  def test_core_commands_override_markdown_conflicts
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)
    File.write(File.join(commands_dir, "help.md"), <<~MD)
      ---
      command: /help
      description: Custom help
      ---

      This should not override core help.
    MD

    catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: @registry)

    assert_equal :cmd_help, catalog.command_map["/help"]
    assert_equal "Show help message", catalog.command_descriptions["/help"]
    report = catalog.reload!
    assert_equal 1, report[:conflicts]
    assert_equal ["/help"], report[:conflict_commands]
    assert_equal ["help.md"], report[:conflict_files]
  end

  def test_reload_report_tracks_added_removed_and_invalid
    commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(commands_dir)
    File.write(File.join(commands_dir, "review.md"), <<~MD)
      ---
      command: /review
      description: Review the code
      ---

      Review the code and suggest improvements.
    MD

    catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: @registry)
    initial = catalog.reload!
    assert_equal 1, initial[:total]
    assert_equal 1, initial[:added]
    assert_equal 0, initial[:removed]
    assert_equal 0, initial[:invalid]
    assert_equal [], initial[:invalid_files]
    assert_equal 0, initial[:conflicts]

    File.delete(File.join(commands_dir, "review.md"))
    File.write(File.join(commands_dir, "broken.md"), "# invalid")

    second = catalog.reload!
    assert_equal 0, second[:total]
    assert_equal 0, second[:added]
    assert_equal 1, second[:removed]
    assert_equal 1, second[:invalid]
    assert_equal ["broken.md"], second[:invalid_files]
    assert_equal 0, second[:conflicts]
  end

  class CommandPlugin < RubyCoded::Plugins::Base
    def self.plugin_name = :command_test
    def self.commands = { "/deploy" => :cmd_deploy }
    def self.command_descriptions = { "/deploy" => "Deploy the app" }
  end
end
