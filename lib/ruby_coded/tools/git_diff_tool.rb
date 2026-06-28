# frozen_string_literal: true

require_relative "git_base_tool"

module RubyCoded
  module Tools
    # Show git diff output for the project repository.
    class GitDiffTool < GitBaseTool
      description "Show git diff output for the project repository. By default shows unstaged changes."
      risk :safe

      params do
        boolean :staged, description: "Show staged changes instead of unstaged changes", required: false
      end

      def execute(staged: false)
        args = ["diff"]
        args << "--cached" if staged
        run_git_command(*args)
      end
    end
  end
end
