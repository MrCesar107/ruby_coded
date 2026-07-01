# frozen_string_literal: true

require "test_helper"
require "ruby_coded/skills/markdown_loader"

class TestSkillMarkdownLoader < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @skills_dir = File.join(@tmpdir, ".rubycoded", "skills")
    FileUtils.mkdir_p(@skills_dir)
    @loader = RubyCoded::Skills::MarkdownLoader.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_loads_valid_skill
    File.write(File.join(@skills_dir, "rails.md"), <<~MD)
      ---
      name: Rails Safety
      description: Prefer Rails conventions and safe migrations
      modes:
        - agent
        - plan
      tags:
        - rails
        - migration
      trigger: schema
      priority: 5
      ---

      Always inspect existing migrations before adding a new one.
    MD

    result = @loader.load_files

    assert_equal 1, result.size
    assert_equal "Rails Safety", result.first[:name]
    assert_equal %w[agent plan], result.first[:modes]
    assert_equal %w[rails migration], result.first[:tags]
  end

  def test_ignores_file_without_frontmatter
    File.write(File.join(@skills_dir, "invalid.md"), "# no frontmatter\nbody")

    assert_empty @loader.load_files
  end

  def test_ignores_file_without_name
    File.write(File.join(@skills_dir, "invalid.md"), <<~MD)
      ---
      description: Missing name
      modes: [chat]
      ---

      Some body.
    MD

    assert_empty @loader.load_files
  end

  def test_ignores_file_with_unsupported_mode
    File.write(File.join(@skills_dir, "invalid.md"), <<~MD)
      ---
      name: Invalid mode
      description: bad mode
      modes: [deploy]
      ---

      Some body.
    MD

    assert_empty @loader.load_files
  end

  def test_ignores_file_with_empty_body
    File.write(File.join(@skills_dir, "invalid.md"), <<~MD)
      ---
      name: Empty Body
      description: Skill with no body
      modes: [chat]
      ---
    MD

    assert_empty @loader.load_files
  end

  def test_load_report_counts_invalid_files
    File.write(File.join(@skills_dir, "valid.md"), <<~MD)
      ---
      name: Valid Skill
      description: Valid description
      modes: [chat]
      ---

      Valid body.
    MD

    File.write(File.join(@skills_dir, "invalid.md"), "# invalid")

    report = @loader.load_report

    assert_equal 1, report[:entries].size
    assert_equal 1, report[:invalid_count]
    assert_equal ["invalid.md"], report[:invalid_files]
  end
end
