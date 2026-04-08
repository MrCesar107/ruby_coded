# frozen_string_literal: true

require "ruby_llm"
require_relative "tool_rejected_error"

module RubyCode
  module Tools
    # Base class for all tools.
    class BaseTool < RubyLLM::Tool
      SAFE_RISK = :safe
      CONFIRM_RISK = :confirm
      DANGEROUS_RISK = :dangerous

      class << self
        attr_reader :risk_level

        private

        def risk(level)
          @risk_level = level
        end
      end

      def initialize(project_root:)
        @project_root = File.realpath(project_root)
      end

      private

      def resolve_path(relative_path)
        expanded = File.expand_path(relative_path, @project_root)
        File.realpath(expanded)
      rescue Errno::ENOENT
        expanded
      end

      def inside_project?(full_path)
        full_path.start_with?(@project_root)
      end

      def validate_path!(relative_path)
        full = resolve_path(relative_path)
        return full if inside_project?(full)

        { error: "Path is outside the project directory. Only paths within #{@project_root} are allowed." }
      end
    end
  end
end
