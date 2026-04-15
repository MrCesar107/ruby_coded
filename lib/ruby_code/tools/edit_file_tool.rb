# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # Replace a specific text occurrence in an existing file (search and replace)
    class EditFileTool < BaseTool
      description "Replace a specific text occurrence in an existing file (search and replace)"
      risk :confirm

      params do
        string :path, description: "Relative file path from the project root"
        string :old_text, description: "The exact text to find in the file (must match exactly)"
        string :new_text, description: "The replacement text"
      end

      def execute(path:, old_text:, new_text:)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "File not found: #{path}" } unless File.exist?(full_path)
        return { error: "Not a file: #{path}" } unless File.file?(full_path)

        apply_edit(path, full_path, old_text, new_text)
      rescue SystemCallError => e
        { error: "Failed to edit #{path}: #{e.message}" }
      end

      private

      def apply_edit(path, full_path, old_text, new_text)
        original = File.read(full_path)
        return { error: "old_text not found in #{path}" } unless original.include?(old_text)

        File.write(full_path, original.sub(old_text, new_text))
        "File edited: #{path}"
      end
    end
  end
end
