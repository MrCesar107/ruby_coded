# frozen_string_literal: true

require_relative "read_file_tool"
require_relative "list_directory_tool"
require_relative "write_file_tool"
require_relative "edit_file_tool"
require_relative "create_directory_tool"
require_relative "delete_path_tool"
require_relative "run_command_tool"

module RubyCode
  module Tools
    # Builds and manages the set of tools available to the LLM in agentic mode.
    class Registry
      READONLY_TOOL_CLASSES = [
        ReadFileTool,
        ListDirectoryTool
      ].freeze

      TOOL_CLASSES = [
        *READONLY_TOOL_CLASSES,
        WriteFileTool,
        EditFileTool,
        CreateDirectoryTool,
        DeletePathTool,
        RunCommandTool
      ].freeze

      def initialize(project_root:)
        @project_root = project_root
      end

      def build_tools
        @build_tools ||= TOOL_CLASSES.map { |klass| klass.new(project_root: @project_root) }
      end

      def build_readonly_tools
        @build_readonly_tools ||= READONLY_TOOL_CLASSES.map { |klass| klass.new(project_root: @project_root) }
      end

      def safe_tool?(tool_call_name)
        klass = find_tool_class(tool_call_name)
        klass && klass.risk_level == BaseTool::SAFE_RISK
      end

      def risk_level_for(tool_call_name)
        klass = find_tool_class(tool_call_name)
        klass&.risk_level || BaseTool::DANGEROUS_RISK
      end

      private

      # RubyLLM may send the tool name as the short form ("read_file_tool")
      # or the full namespaced form ("ruby_code--tools--read_file_tool").
      # Match on the short class-derived name against the last segment.
      def find_tool_class(tool_call_name)
        short = tool_call_name.split("--").last
        TOOL_CLASSES.find { |k| [short, tool_call_name].include?(tool_name_for(k)) }
      end

      def tool_name_for(klass)
        klass.name.split("::").last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      end
    end
  end
end
