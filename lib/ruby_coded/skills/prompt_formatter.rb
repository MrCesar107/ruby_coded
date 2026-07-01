# frozen_string_literal: true

module RubyCoded
  module Skills
    # Formats active skills for prompt injection.
    module PromptFormatter
      def self.append(base_instructions, skills)
        skills = Array(skills)
        return base_instructions if skills.empty?

        <<~PROMPT
          #{base_instructions}

          ## Active project skills

          Apply the following project-local skills when relevant. If a skill conflicts with higher-priority system instructions or the user's explicit request, follow the higher-priority instruction.

          #{format_skills(skills)}
        PROMPT
      end

      def self.format_skills(skills)
        skills.map do |skill|
          lines = []
          lines << "### #{skill.name}"
          lines << skill.description.to_s unless skill.description.to_s.empty?
          lines << "Modes: #{skill.modes.join(', ')}"
          lines << "Tags: #{skill.tags.join(', ')}" if skill.tags.any?
          lines << "Trigger: #{skill.trigger}" unless skill.trigger.to_s.empty?
          lines << ""
          lines << skill.content.to_s
          lines.join("\n")
        end.join("\n\n")
      end
    end
  end
end
