# frozen_string_literal: true

module RubyCode
  module Chat
    # Parses <clarification> tags from LLM responses in plan mode.
    # Extracts a single question and its options for the UI.
    module PlanClarificationParser
      CLARIFICATION_REGEX = %r{<clarification>\s*(.*?)\s*</clarification>}m
      QUESTION_REGEX = %r{<question>\s*(.*?)\s*</question>}m
      OPTION_REGEX = %r{<option>\s*(.*?)\s*</option>}m

      def self.clarification?(content)
        CLARIFICATION_REGEX.match?(content)
      end

      # Returns { question: String, options: [String], preamble: String }
      # or nil if no clarification tags are found.
      def self.parse(content)
        match = CLARIFICATION_REGEX.match(content)
        return nil unless match

        inner = match[1]
        question = QUESTION_REGEX.match(inner)&.[](1)&.strip
        options = inner.scan(OPTION_REGEX).flatten.map(&:strip)

        return nil unless question && options.size >= 2

        preamble = content[0...match.begin(0)].strip

        { question: question, options: options, preamble: preamble }
      end

      def self.strip_clarification(content)
        content.sub(CLARIFICATION_REGEX, "").strip
      end
    end
  end
end
