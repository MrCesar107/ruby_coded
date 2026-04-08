# frozen_string_literal: true

require "test_helper"
require "ruby_code/tools/read_file_tool"
require "ruby_code/tools/list_directory_tool"
require "ruby_code/tools/write_file_tool"
require "ruby_code/tools/edit_file_tool"
require "ruby_code/tools/create_directory_tool"
require "ruby_code/tools/delete_path_tool"
require "ruby_code/tools/run_command_tool"

class TestReadFileTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::ReadFileTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_reads_existing_file
    File.write(File.join(@tmpdir, "hello.txt"), "Hello World")
    result = @tool.execute(path: "hello.txt")
    assert_equal "Hello World", result
  end

  def test_returns_error_for_missing_file
    result = @tool.execute(path: "missing.txt")
    assert_equal({ error: "File not found: missing.txt" }, result)
  end

  def test_returns_error_for_directory
    Dir.mkdir(File.join(@tmpdir, "subdir"))
    result = @tool.execute(path: "subdir")
    assert_equal({ error: "Not a file: subdir" }, result)
  end

  def test_returns_error_for_path_outside_project
    result = @tool.execute(path: "../../etc/passwd")
    assert result.is_a?(Hash)
    assert result[:error].include?("outside the project")
  end

  def test_returns_error_for_empty_file
    File.write(File.join(@tmpdir, "empty.txt"), "")
    result = @tool.execute(path: "empty.txt")
    assert_equal({ error: "File is empty" }, result)
  end

  def test_risk_level_is_safe
    assert_equal :safe, RubyCode::Tools::ReadFileTool.risk_level
  end
end

class TestListDirectoryTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::ListDirectoryTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_lists_directory_contents
    File.write(File.join(@tmpdir, "file.txt"), "content")
    Dir.mkdir(File.join(@tmpdir, "subdir"))

    result = @tool.execute(path: ".")
    assert_includes result, "file  file.txt"
    assert_includes result, "dir  subdir"
  end

  def test_returns_error_for_missing_directory
    result = @tool.execute(path: "nonexistent")
    assert_equal({ error: "Directory not found: nonexistent" }, result)
  end

  def test_returns_error_for_file_path
    File.write(File.join(@tmpdir, "file.txt"), "content")
    result = @tool.execute(path: "file.txt")
    assert_equal({ error: "Not a directory: file.txt" }, result)
  end

  def test_returns_empty_message_for_empty_directory
    Dir.mkdir(File.join(@tmpdir, "empty"))
    result = @tool.execute(path: "empty")
    assert_equal "(empty directory)", result
  end

  def test_returns_error_for_path_outside_project
    result = @tool.execute(path: "../../")
    assert result.is_a?(Hash)
    assert result[:error].include?("outside the project")
  end

  def test_risk_level_is_safe
    assert_equal :safe, RubyCode::Tools::ListDirectoryTool.risk_level
  end
end

class TestWriteFileTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::WriteFileTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_creates_new_file
    result = @tool.execute(path: "new.txt", content: "Hello")
    assert_includes result, "File written: new.txt"
    assert_equal "Hello", File.read(File.join(@tmpdir, "new.txt"))
  end

  def test_creates_intermediate_directories
    result = @tool.execute(path: "a/b/c.txt", content: "deep")
    assert_includes result, "File written: a/b/c.txt"
    assert_equal "deep", File.read(File.join(@tmpdir, "a", "b", "c.txt"))
  end

  def test_overwrites_existing_file
    File.write(File.join(@tmpdir, "existing.txt"), "old")
    result = @tool.execute(path: "existing.txt", content: "new")
    assert_includes result, "File written"
    assert_equal "new", File.read(File.join(@tmpdir, "existing.txt"))
  end

  def test_returns_error_for_path_outside_project
    result = @tool.execute(path: "../../evil.txt", content: "bad")
    assert result.is_a?(Hash)
    assert result[:error].include?("outside the project")
  end

  def test_risk_level_is_confirm
    assert_equal :confirm, RubyCode::Tools::WriteFileTool.risk_level
  end
end

class TestEditFileTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::EditFileTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_replaces_text_in_file
    File.write(File.join(@tmpdir, "code.rb"), "puts 'hello'\nputs 'world'")
    result = @tool.execute(path: "code.rb", old_text: "hello", new_text: "goodbye")
    assert_includes result, "File edited"
    assert_equal "puts 'goodbye'\nputs 'world'", File.read(File.join(@tmpdir, "code.rb"))
  end

  def test_returns_error_when_text_not_found
    File.write(File.join(@tmpdir, "code.rb"), "puts 'hello'")
    result = @tool.execute(path: "code.rb", old_text: "nonexistent", new_text: "replacement")
    assert_equal({ error: "old_text not found in code.rb" }, result)
  end

  def test_returns_error_for_missing_file
    result = @tool.execute(path: "missing.rb", old_text: "a", new_text: "b")
    assert_equal({ error: "File not found: missing.rb" }, result)
  end

  def test_replaces_only_first_occurrence
    File.write(File.join(@tmpdir, "multi.txt"), "aaa\naaa")
    @tool.execute(path: "multi.txt", old_text: "aaa", new_text: "bbb")
    assert_equal "bbb\naaa", File.read(File.join(@tmpdir, "multi.txt"))
  end

  def test_risk_level_is_confirm
    assert_equal :confirm, RubyCode::Tools::EditFileTool.risk_level
  end
end

class TestCreateDirectoryTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::CreateDirectoryTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_creates_directory
    result = @tool.execute(path: "newdir")
    assert_includes result, "Directory created"
    assert File.directory?(File.join(@tmpdir, "newdir"))
  end

  def test_creates_nested_directories
    result = @tool.execute(path: "a/b/c")
    assert_includes result, "Directory created"
    assert File.directory?(File.join(@tmpdir, "a", "b", "c"))
  end

  def test_reports_existing_directory
    Dir.mkdir(File.join(@tmpdir, "existing"))
    result = @tool.execute(path: "existing")
    assert_includes result, "already exists"
  end

  def test_returns_error_when_path_is_a_file
    File.write(File.join(@tmpdir, "file.txt"), "content")
    result = @tool.execute(path: "file.txt")
    assert result.is_a?(Hash)
    assert result[:error].include?("already exists")
  end

  def test_risk_level_is_confirm
    assert_equal :confirm, RubyCode::Tools::CreateDirectoryTool.risk_level
  end
end

class TestDeletePathTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::DeletePathTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_deletes_file
    path = File.join(@tmpdir, "doomed.txt")
    File.write(path, "goodbye")
    result = @tool.execute(path: "doomed.txt")
    assert_includes result, "Deleted file"
    refute File.exist?(path)
  end

  def test_deletes_empty_directory
    Dir.mkdir(File.join(@tmpdir, "emptydir"))
    result = @tool.execute(path: "emptydir")
    assert_includes result, "Deleted empty directory"
    refute File.exist?(File.join(@tmpdir, "emptydir"))
  end

  def test_refuses_to_delete_non_empty_directory
    Dir.mkdir(File.join(@tmpdir, "fulldir"))
    File.write(File.join(@tmpdir, "fulldir", "file.txt"), "x")
    result = @tool.execute(path: "fulldir")
    assert result.is_a?(Hash)
    assert result[:error].include?("not empty")
  end

  def test_returns_error_for_missing_path
    result = @tool.execute(path: "ghost")
    assert_equal({ error: "Path not found: ghost" }, result)
  end

  def test_refuses_to_delete_project_root
    result = @tool.execute(path: ".")
    assert result.is_a?(Hash)
    assert result[:error].include?("Cannot delete the project root")
  end

  def test_risk_level_is_dangerous
    assert_equal :dangerous, RubyCode::Tools::DeletePathTool.risk_level
  end
end

class TestRunCommandTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCode::Tools::RunCommandTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_executes_simple_command
    result = @tool.execute(command: "echo hello")
    assert_includes result, "hello"
    assert_includes result, "Exit code: 0"
  end

  def test_captures_stderr
    result = @tool.execute(command: "echo error >&2")
    assert_includes result, "STDERR"
    assert_includes result, "error"
  end

  def test_returns_error_for_missing_command
    result = @tool.execute(command: "nonexistent_cmd_12345")
    # Depending on shell, this could be an error hash or contain exit code
    assert(result.is_a?(Hash) || result.include?("Exit code:"))
  end

  def test_risk_level_is_dangerous
    assert_equal :dangerous, RubyCode::Tools::RunCommandTool.risk_level
  end
end
