# frozen_string_literal: true

require_relative "skill_definition"
require_relative "markdown_loader"

module RubyCoded
  module Skills
    # Loads, validates, and caches project-local skill definitions.
    class Catalog
      def initialize(project_root:)
        @project_root = project_root
        @last_reload_report = nil
      end

      def all_skills
        valid_skills.sort_by { |skill| [-skill.priority, skill.name.downcase] }
      end

      def skills_for_mode(mode)
        all_skills.select { |skill| skill.applies_to_mode?(mode) }
      end

      def relevant_skills_for(mode:, input: nil)
        mode_skills = skills_for_mode(mode)
        return mode_skills if input.to_s.strip.empty?

        matched = mode_skills.select { |skill| matches_input?(skill, input) }
        matched.empty? ? mode_skills : matched.sort_by { |skill| [-skill.priority, skill.name.downcase] }
      end

      def reload!
        previous_names = cached_skill_names
        clear_cached_reports!
        current_names = valid_skills.map { |skill| skill.name.downcase }
        @last_reload_report = build_reload_report(previous_names, current_names)
      end

      def last_reload_report
        @last_reload_report || default_reload_report
      end

      private

      def cached_skill_names
        return [] unless @valid_skills

        @valid_skills.map { |skill| skill.name.downcase }
      end

      def clear_cached_reports!
        @load_report = nil
        @valid_skills = nil
      end

      def default_reload_report
        build_reload_report([], valid_skills.map { |skill| skill.name.downcase }).merge(added: 0)
      end

      def build_reload_report(previous_names, current_names)
        {
          total: current_names.size,
          added: (current_names - previous_names).size,
          removed: (previous_names - current_names).size,
          invalid: load_report[:invalid_count],
          invalid_files: load_report[:invalid_files],
          duplicates: duplicate_names.size,
          duplicate_skills: duplicate_names
        }
      end

      def valid_skills
        @valid_skills ||= begin
          seen = {}
          skills = []

          load_report[:entries].each do |entry|
            key = entry[:name].downcase
            next if seen[key]

            seen[key] = true
            skills << build_definition(entry)
          end

          skills
        end
      end

      def duplicate_names
        counts = Hash.new(0)
        load_report[:entries].each { |entry| counts[entry[:name].downcase] += 1 }
        counts.select { |_name, count| count > 1 }.keys.sort
      end

      def build_definition(entry)
        SkillDefinition.new(**entry)
      end

      def matches_input?(skill, input)
        haystack = input.to_s.downcase
        trigger_match = !skill.trigger.to_s.empty? && haystack.include?(skill.trigger.downcase)
        tag_match = skill.tags.any? { |tag| haystack.include?(tag.downcase) }
        trigger_match || tag_match
      end

      def loader
        @loader ||= MarkdownLoader.new(project_root: @project_root)
      end

      def load_report
        @load_report ||= loader.load_report
      end
    end
  end
end
