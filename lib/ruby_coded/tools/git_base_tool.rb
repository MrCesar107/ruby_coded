# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "base_tool"

module RubyCoded
  module Tools
    # Shared helpers for git-specific tools.
    class GitBaseTool < BaseTool
      GIT_ENV = {
        "GIT_EDITOR" => "true",
        "EDITOR" => "true",
        "VISUAL" => "true",
        "GIT_PAGER" => "cat",
        "PAGER" => "cat"
      }.freeze

      MAX_OUTPUT_CHARS = 5000

      def git_repo?
        Dir.exist?(File.join(@project_root, ".git"))
      end

      def ensure_git_repo!
        return nil if git_repo?

        { error: "Not a git repository: #{@project_root}" }
      end

      def run_git_command(*)
        repo_error = ensure_git_repo!
        return repo_error if repo_error

        stdout, stderr, status = Open3.capture3(GIT_ENV, "git", *, chdir: @project_root)
        format_git_result(stdout, stderr, status)
      rescue Errno::ENOENT => e
        { error: "Git executable not found: #{e.message}" }
      rescue StandardError => e
        { error: "Git command failed: #{e.message}" }
      end

      def format_git_result(stdout, stderr, status)
        output = String.new
        output << stdout unless stdout.empty?
        output << "\nSTDERR:\n#{stderr}" unless stderr.empty?
        output = output.strip
        output = "(no output)" if output.empty?
        output = truncate_output(output)

        return output if status.success?

        { error: output }
      end

      def truncate_output(output)
        return output if output.length <= MAX_OUTPUT_CHARS

        "#{output[0, MAX_OUTPUT_CHARS]}...(truncated, #{output.length} total characters)"
      end

      def shell_join(parts)
        parts.map { |part| Shellwords.escape(part.to_s) }.join(" ")
      end
    end
  end
end
