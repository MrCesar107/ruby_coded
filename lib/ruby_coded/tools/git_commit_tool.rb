# frozen_string_literal: true

require_relative "git_base_tool"

module RubyCoded
  module Tools
    # Create a non-interactive git commit.
    class GitCommitTool < GitBaseTool
      description "Create a git commit with a message. Supports staging all changes first if requested."
      risk :confirm

      params do
        string :message, description: "Commit message"
        boolean :add_all, description: "Stage all changes before committing", required: false
      end

      def execute(message:, add_all: false)
        msg = message.to_s.strip
        return { error: "Commit message cannot be empty." } if msg.empty?

        if add_all
          add_result = run_git_command("add", "--all")
          return add_result if add_result.is_a?(Hash)
        end

        result = run_git_command("commit", "-m", msg)
        return enhance_commit_error(result) if result.is_a?(Hash)

        prefix = add_all ? "Staged all changes and created commit." : "Created commit."
        "#{prefix}\n#{result}"
      end

      private

      def enhance_commit_error(result)
        message = result[:error].to_s

        return { error: "Nothing to commit. Working tree clean or no staged changes." } if message.include?("nothing to commit")
        return { error: "Git user identity is not configured. Set user.name and user.email before committing." } if message.include?("Author identity unknown")

        result
      end
    end
  end
end
