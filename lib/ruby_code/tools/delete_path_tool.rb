# frozen_string_literal: true

require "fileutils"
require_relative "base_tool"

module RubyCode
  module Tools
    # Delete a file or an empty directory at the given path
    class DeletePathTool < BaseTool
      description "Delete a file or an empty directory at the given path"
      risk :dangerous

      params do
        string :path, description: "Relative path from the project root to delete"
      end

      def execute(path:)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "Path not found: #{path}" } unless File.exist?(full_path)
        return { error: "Cannot delete the project root" } if full_path == @project_root

        if File.directory?(full_path)
          delete_directory(path, full_path)
        else
          File.delete(full_path)
          "Deleted file: #{path}"
        end
      rescue SystemCallError => e
        { error: "Failed to delete #{path}: #{e.message}" }
      end

      private

      def delete_directory(path, full_path)
        entries = Dir.children(full_path)
        unless entries.empty?
          return { error: "Directory not empty: #{path} (#{entries.length} entries). Remove contents first." }
        end

        Dir.rmdir(full_path)
        "Deleted empty directory: #{path}"
      end
    end
  end
end
