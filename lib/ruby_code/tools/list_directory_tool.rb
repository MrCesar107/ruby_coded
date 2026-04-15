# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # List files and directories at the given path relative to the project root
    class ListDirectoryTool < BaseTool
      description "List files and directories at the given path relative to the project root. " \
                  "Set include_hidden to true to include hidden/ignored directories."
      risk :safe

      IGNORED_DIRS = %w[
        .git node_modules vendor/bundle tmp log .bundle
        .cache coverage .yardoc pkg dist build
      ].freeze

      params do
        string :path, description: "Relative directory path from the project root (use '.' for root)"
        boolean :include_hidden, description: "Include hidden and commonly ignored directories (default: false)",
                                 required: false
      end

      def execute(path:, include_hidden: false)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "Directory not found: #{path}" } unless File.exist?(full_path)
        return { error: "Not a directory: #{path}" } unless File.directory?(full_path)

        list_entries(full_path, include_hidden)
      end

      private

      def list_entries(full_path, include_hidden)
        children = Dir.children(full_path).sort
        children = children.reject { |name| ignored_entry?(name) } unless include_hidden

        entries = children.map do |name|
          entry_path = File.join(full_path, name)
          type = File.directory?(entry_path) ? "dir" : "file"
          "#{type}  #{name}"
        end

        entries.empty? ? "(empty directory)" : entries.join("\n")
      end

      def ignored_entry?(name)
        IGNORED_DIRS.include?(name)
      end
    end
  end
end
