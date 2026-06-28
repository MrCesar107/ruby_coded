# frozen_string_literal: true

require_relative "git_base_tool"

module RubyCoded
  module Tools
    # Stage specific files or all current changes in the git repository.
    class GitAddTool < GitBaseTool
      description "Stage files in the git repository. Provide paths or set all to true to stage everything."
      risk :confirm

      params do
        array :paths, of: :string,
                      description: "Relative file paths to stage",
                      required: false
        boolean :all, description: "Stage all tracked and untracked changes", required: false
      end

      def execute(paths: nil, all: false)
        return stage_all if all

        stage_paths(paths)
      end

      private

      def stage_all
        result = run_git_command("add", "--all")
        return result if result.is_a?(Hash)

        "Staged all changes.\n#{result}"
      end

      def stage_paths(paths)
        normalized_paths = Array(paths).map(&:to_s).reject(&:empty?)
        return { error: "Provide at least one path or set all to true." } if normalized_paths.empty?

        invalid = invalid_paths(normalized_paths)
        return { error: "Paths are outside the project directory: #{invalid.join(", ")}" } unless invalid.empty?

        result = run_git_command("add", *normalized_paths)
        return result if result.is_a?(Hash)

        "Staged paths: #{normalized_paths.join(", ")}\n#{result}"
      end

      def invalid_paths(normalized_paths)
        normalized_paths.filter_map do |path|
          validated = validate_path!(path)
          path if validated.is_a?(Hash)
        end
      end
    end
  end
end
