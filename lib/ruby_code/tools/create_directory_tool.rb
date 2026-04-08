# frozen_string_literal: true

require "fileutils"
require_relative "base_tool"

module RubyCode
  module Tools
    # Create a directory (and any necessary parent directories) at the given path
    class CreateDirectoryTool < BaseTool
      description "Create a directory (and any necessary parent directories) at the given path"
      risk :confirm

      params do
        string :path, description: "Relative directory path from the project root"
      end

      def execute(path:)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)

        if File.exist?(full_path)
          return { error: "Path already exists: #{path}" } unless File.directory?(full_path)

          return "Directory already exists: #{path}"
        end

        FileUtils.mkdir_p(full_path)
        "Directory created: #{path}"
      rescue SystemCallError => e
        { error: "Failed to create directory #{path}: #{e.message}" }
      end
    end
  end
end
