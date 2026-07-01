# frozen_string_literal: true

require "test_helper"
require "ruby_coded/skills/catalog"

class TestSkillCatalog < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @skills_dir = File.join(@tmpdir, ".rubycoded", "skills")
    FileUtils.mkdir_p(@skills_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_filters_skills_by_mode
    write_skill("plan.md", <<~MD)
      ---
      name: Planner
      description: Planning help
      modes: [plan]
      ---

      Break work into steps.
    MD

    write_skill("agent.md", <<~MD)
      ---
      name: Builder
      description: Agent help
      modes: [agent]
      ---

      Read files before editing.
    MD

    catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)

    assert_equal ["Planner"], catalog.skills_for_mode(:plan).map(&:name)
    assert_equal ["Builder"], catalog.skills_for_mode(:agent).map(&:name)
  end

  def test_duplicate_skill_names_are_ignored_after_first
    write_skill("one.md", <<~MD)
      ---
      name: Rails Skill
      description: First
      modes: [chat]
      ---

      First body.
    MD

    write_skill("two.md", <<~MD)
      ---
      name: Rails Skill
      description: Second
      modes: [chat]
      ---

      Second body.
    MD

    catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)
    report = catalog.reload!

    assert_equal 1, catalog.all_skills.size
    assert_equal 1, report[:duplicates]
    assert_equal ["rails skill"], report[:duplicate_skills]
  end

  def test_relevant_skills_match_input_by_trigger_or_tag
    write_skill("rails.md", <<~MD)
      ---
      name: Rails Skill
      description: Rails help
      modes: [agent]
      tags: [active record]
      trigger: migration
      priority: 10
      ---

      Check schema impact.
    MD

    write_skill("generic.md", <<~MD)
      ---
      name: Generic Skill
      description: Generic help
      modes: [agent]
      ---

      General advice.
    MD

    catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)

    matched = catalog.relevant_skills_for(mode: :agent, input: "add a migration for active record")
    assert_equal ["Rails Skill"], matched.map(&:name)
  end

  def test_relevant_skills_fall_back_to_all_mode_skills_when_no_match
    write_skill("generic.md", <<~MD)
      ---
      name: Generic Skill
      description: Generic help
      modes: [chat]
      ---

      General advice.
    MD

    catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)

    matched = catalog.relevant_skills_for(mode: :chat, input: "unrelated topic")
    assert_equal ["Generic Skill"], matched.map(&:name)
  end

  private

  def write_skill(filename, content)
    File.write(File.join(@skills_dir, filename), content)
  end
end
