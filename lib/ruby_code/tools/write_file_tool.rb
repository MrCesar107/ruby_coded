# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # Create a new file or overwrite an existing file with the given content
    class WriteFileTool < BaseTool
      description "Create a new file or overwrite an existing file with the given content"
      risk :confirm

      params do
        string :path, description: "Relative file path from the project root"
        string :content, description: "The full content to write into the file"
      end

      def execute(path:, content:)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)

        dir = File.dirname(full_path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)

        File.write(full_path, content)
        "File written: #{path} (#{content.bytesize} bytes)"
      rescue SystemCallError => e
        { error: "Failed to write #{path}: #{e.message}" }
      end
    end
  end
end
