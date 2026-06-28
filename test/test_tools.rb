# frozen_string_literal: true

require "test_helper"
require "ruby_coded/tools/read_file_tool"
require "ruby_coded/tools/list_directory_tool"
require "ruby_coded/tools/write_file_tool"
require "ruby_coded/tools/edit_file_tool"
require "ruby_coded/tools/create_directory_tool"
require "ruby_coded/tools/delete_path_tool"
require "ruby_coded/tools/run_command_tool"
require "ruby_coded/tools/git_status_tool"
require "ruby_coded/tools/git_diff_tool"
require "ruby_coded/tools/git_add_tool"
require "ruby_coded/tools/git_commit_tool"

class TestReadFileTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::ReadFileTool.new(project_root: @tmpdir)
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
    assert_equal :safe, RubyCoded::Tools::ReadFileTool.risk_level
  end
end

class TestListDirectoryTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::ListDirectoryTool.new(project_root: @tmpdir)
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
    assert_equal :safe, RubyCoded::Tools::ListDirectoryTool.risk_level
  end
end

class TestWriteFileTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::WriteFileTool.new(project_root: @tmpdir)
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
    assert_equal :confirm, RubyCoded::Tools::WriteFileTool.risk_level
  end
end

class TestEditFileTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::EditFileTool.new(project_root: @tmpdir)
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
    assert_equal :confirm, RubyCoded::Tools::EditFileTool.risk_level
  end
end

class TestCreateDirectoryTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::CreateDirectoryTool.new(project_root: @tmpdir)
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
    assert_equal :confirm, RubyCoded::Tools::CreateDirectoryTool.risk_level
  end
end

class TestDeletePathTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::DeletePathTool.new(project_root: @tmpdir)
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
    assert_equal :dangerous, RubyCoded::Tools::DeletePathTool.risk_level
  end
end

class TestRunCommandTool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @tool = RubyCoded::Tools::RunCommandTool.new(project_root: @tmpdir)
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

  def test_git_commands_run_non_interactively
    setup_git_repo(@tmpdir)
    File.write(File.join(@tmpdir, "note.txt"), "hello\n")
    run_git(@tmpdir, "add", "note.txt")
    result = @tool.execute(command: "git commit -m 'test commit'")
    assert_includes result, "Exit code: 0"
    assert_includes result, "test commit"
  end

  def test_returns_error_for_missing_command
    result = @tool.execute(command: "nonexistent_cmd_12345")
    # Depending on shell, this could be an error hash or contain exit code
    assert(result.is_a?(Hash) || result.include?("Exit code:"))
  end

  def test_risk_level_is_dangerous
    assert_equal :dangerous, RubyCoded::Tools::RunCommandTool.risk_level
  end
end

class TestGitTools < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    setup_git_repo(@tmpdir)
    @status_tool = RubyCoded::Tools::GitStatusTool.new(project_root: @tmpdir)
    @diff_tool = RubyCoded::Tools::GitDiffTool.new(project_root: @tmpdir)
    @add_tool = RubyCoded::Tools::GitAddTool.new(project_root: @tmpdir)
    @commit_tool = RubyCoded::Tools::GitCommitTool.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_git_status_is_safe
    assert_equal :safe, RubyCoded::Tools::GitStatusTool.risk_level
  end

  def test_git_diff_is_safe
    assert_equal :safe, RubyCoded::Tools::GitDiffTool.risk_level
  end

  def test_git_add_is_confirm
    assert_equal :confirm, RubyCoded::Tools::GitAddTool.risk_level
  end

  def test_git_commit_is_confirm
    assert_equal :confirm, RubyCoded::Tools::GitCommitTool.risk_level
  end

  def test_git_status_reports_branch
    result = @status_tool.execute
    assert_includes result, "##"
  end

  def test_git_diff_shows_unstaged_changes
    path = File.join(@tmpdir, "note.txt")
    File.write(path, "hello\n")
    @add_tool.execute(paths: ["note.txt"])
    @commit_tool.execute(message: "Add note")

    File.write(path, "hello\nworld\n")
    result = @diff_tool.execute
    assert_includes result, "note.txt"
  end

  def test_git_add_stages_specific_paths
    File.write(File.join(@tmpdir, "note.txt"), "hello\n")
    result = @add_tool.execute(paths: ["note.txt"])
    assert_includes result, "Staged paths: note.txt"

    status = @status_tool.execute
    assert_includes status, "A  note.txt"
  end

  def test_git_add_all_stages_everything
    File.write(File.join(@tmpdir, "one.txt"), "1")
    File.write(File.join(@tmpdir, "two.txt"), "2")
    result = @add_tool.execute(all: true)
    assert_includes result, "Staged all changes"
  end

  def test_git_commit_creates_commit
    File.write(File.join(@tmpdir, "note.txt"), "hello\n")
    @add_tool.execute(paths: ["note.txt"])
    result = @commit_tool.execute(message: "Add note")
    assert_includes result, "Created commit"
    assert_includes result, "Add note"
  end

  def test_git_commit_can_stage_all_first
    File.write(File.join(@tmpdir, "note.txt"), "hello\n")
    result = @commit_tool.execute(message: "Add note", add_all: true)
    assert_includes result, "Staged all changes and created commit"
  end

  def test_git_commit_returns_clear_error_when_nothing_to_commit
    result = @commit_tool.execute(message: "Empty commit")
    assert_equal({ error: "Nothing to commit. Working tree clean or no staged changes." }, result)
  end

  def test_git_tools_fail_outside_repo
    outside = File.realpath(Dir.mktmpdir)
    begin
      tool = RubyCoded::Tools::GitStatusTool.new(project_root: outside)
      result = tool.execute
      assert_equal({ error: "Not a git repository: #{outside}" }, result)
    ensure
      FileUtils.remove_entry(outside)
    end
  end
end

private

def setup_git_repo(dir)
  run_git(dir, "init")
  run_git(dir, "config", "user.name", "RubyCoded Test")
  run_git(dir, "config", "user.email", "test@example.com")
end

def run_git(dir, *args)
  env = {
    "GIT_EDITOR" => "true",
    "EDITOR" => "true",
    "VISUAL" => "true",
    "GIT_PAGER" => "cat",
    "PAGER" => "cat"
  }
  stdout, stderr, status = Open3.capture3(env, "git", *args, chdir: dir)
  raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

  stdout
end
