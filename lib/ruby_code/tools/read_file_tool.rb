# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # Read the contents of a file at the given path relative to the project root
    class ReadFileTool < BaseTool
      description "Read the contents of a file at the given path relative to the project root. " \
                  "Use offset and max_lines to read specific sections of large files."
      risk :safe

      DEFAULT_MAX_LINES = 200

      params do
        string :path, description: "Relative file path from the project root"
        integer :offset, description: "Line number to start reading from (1-based, default: 1)", required: false
        integer :max_lines, description: "Maximum number of lines to return (default: #{DEFAULT_MAX_LINES})",
                            required: false
      end

      def execute(path:, offset: nil, max_lines: nil)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "File not found: #{path}" } unless File.exist?(full_path)
        return { error: "Not a file: #{path}" } unless File.file?(full_path)

        read_file_section(full_path, offset, max_lines)
      end

      private

      def read_file_section(full_path, offset, max_lines)
        lines = File.readlines(full_path)
        return { error: "File is empty" } if lines.empty?

        start_line = [offset || 1, 1].max
        selected = lines[start_line - 1, max_lines || DEFAULT_MAX_LINES] || []

        format_lines_output(selected, start_line, lines.length)
      end

      def format_lines_output(selected, start_line, total)
        result = selected.join
        end_line = start_line - 1 + selected.length
        remaining = total - end_line
        return result unless remaining.positive?

        result << "\n... (showing lines #{start_line}-#{end_line} of #{total}. " \
                  "#{remaining} lines remaining, use offset to read more)"
      end
    end
  end
end
