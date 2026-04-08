# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # Read the contents of a file at the given path relative to the project root
    class ReadFileTool < BaseTool
      description "Read the contents of a file at the given path relative to the project root"
      risk :safe

      params do
        string :path, description: "Relative file path from the project root"
      end

      def execute(path:)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "File not found: #{path}" } unless File.exist?(full_path)
        return { error: "Not a file: #{path}" } unless File.file?(full_path)

        content = File.read(full_path)
        return { error: "File is empty" } if content.empty?

        content
      end
    end
  end
end
