# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # List files and directories at the given path relative to the project root
    class ListDirectoryTool < BaseTool
      description "List files and directories at the given path relative to the project root"
      risk :safe

      params do
        string :path, description: "Relative directory path from the project root (use '.' for root)"
      end

      def execute(path:)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "Directory not found: #{path}" } unless File.exist?(full_path)
        return { error: "Not a directory: #{path}" } unless File.directory?(full_path)

        entries = Dir.children(full_path).sort.map do |name|
          entry_path = File.join(full_path, name)
          type = File.directory?(entry_path) ? "dir" : "file"
          "#{type}  #{name}"
        end

        entries.empty? ? "(empty directory)" : entries.join("\n")
      end
    end
  end
end
