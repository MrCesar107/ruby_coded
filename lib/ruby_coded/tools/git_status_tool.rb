# frozen_string_literal: true

require_relative "git_base_tool"

module RubyCoded
  module Tools
    # Show the current git working tree status.
    class GitStatusTool < GitBaseTool
      description "Show the current git working tree status for the project repository"
      risk :safe

      def execute
        run_git_command("status", "--short", "--branch")
      end
    end
  end
end
