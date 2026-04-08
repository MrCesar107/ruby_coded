# frozen_string_literal: true

require "open3"
require_relative "base_tool"

module RubyCode
  module Tools
    # Execute a shell command in the project directory and return its output
    class RunCommandTool < BaseTool
      description "Execute a shell command in the project directory and return its output"
      risk :dangerous

      TIMEOUT_SECONDS = 30

      params do
        string :command, description: "The shell command to execute"
      end

      def execute(command:)
        stdout, stderr, status = Open3.capture3(command, chdir: @project_root)

        output = String.new
        output << stdout unless stdout.empty?
        output << "\nSTDERR:\n#{stderr}" unless stderr.empty?
        output << "\nExit code: #{status.exitstatus}"

        if output.length > 5000
          "#{output[0..4997]}...(truncated)"
        else
          output
        end
      rescue Errno::ENOENT => e
        { error: "Command not found: #{e.message}" }
      rescue StandardError => e
        { error: "Command failed: #{e.message}" }
      end
    end
  end
end
