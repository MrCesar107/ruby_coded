# frozen_string_literal: true

require "test_helper"
require "ruby_coded/tools/registry"

class TestToolRegistry < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @registry = RubyCoded::Tools::Registry.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_build_tools_returns_all_tool_instances
    tools = @registry.build_tools
    assert_equal RubyCoded::Tools::Registry::TOOL_CLASSES.size, tools.size
    tools.each { |t| assert_kind_of RubyCoded::Tools::BaseTool, t }
  end

  def test_safe_tool_recognizes_read_file
    assert @registry.safe_tool?("read_file_tool")
  end

  def test_safe_tool_recognizes_list_directory
    assert @registry.safe_tool?("list_directory_tool")
  end

  def test_safe_tool_returns_false_for_write_tool
    refute @registry.safe_tool?("write_file_tool")
  end

  def test_safe_tool_returns_false_for_unknown_tool
    refute @registry.safe_tool?("nonexistent_tool")
  end

  def test_risk_level_for_safe_tools
    assert_equal :safe, @registry.risk_level_for("read_file_tool")
    assert_equal :safe, @registry.risk_level_for("list_directory_tool")
    assert_equal :safe, @registry.risk_level_for("git_status_tool")
    assert_equal :safe, @registry.risk_level_for("git_diff_tool")
  end

  def test_risk_level_for_confirm_tools
    assert_equal :confirm, @registry.risk_level_for("write_file_tool")
    assert_equal :confirm, @registry.risk_level_for("edit_file_tool")
    assert_equal :confirm, @registry.risk_level_for("create_directory_tool")
    assert_equal :confirm, @registry.risk_level_for("git_add_tool")
    assert_equal :confirm, @registry.risk_level_for("git_commit_tool")
  end

  def test_risk_level_for_dangerous_tools
    assert_equal :dangerous, @registry.risk_level_for("delete_path_tool")
    assert_equal :dangerous, @registry.risk_level_for("run_command_tool")
  end

  def test_risk_level_for_unknown_defaults_to_dangerous
    assert_equal :dangerous, @registry.risk_level_for("unknown_tool")
  end

  def test_safe_tool_with_namespaced_name
    assert @registry.safe_tool?("ruby_coded--tools--read_file_tool")
    assert @registry.safe_tool?("ruby_coded--tools--list_directory_tool")
    assert @registry.safe_tool?("ruby_coded--tools--git_status_tool")
    assert @registry.safe_tool?("ruby_coded--tools--git_diff_tool")
  end

  def test_risk_level_with_namespaced_name
    assert_equal :safe, @registry.risk_level_for("ruby_coded--tools--read_file_tool")
    assert_equal :safe, @registry.risk_level_for("ruby_coded--tools--git_status_tool")
    assert_equal :confirm, @registry.risk_level_for("ruby_coded--tools--write_file_tool")
    assert_equal :confirm, @registry.risk_level_for("ruby_coded--tools--git_commit_tool")
    assert_equal :dangerous, @registry.risk_level_for("ruby_coded--tools--delete_path_tool")
  end

  def test_namespaced_write_tool_is_not_safe
    refute @registry.safe_tool?("ruby_coded--tools--write_file_tool")
  end
end
