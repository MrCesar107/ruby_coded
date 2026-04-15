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
      MAX_OUTPUT_CHARS = 5000

      params do
        string :command, description: "The shell command to execute"
      end

      def execute(command:)
        stdout, stderr, status = run_with_timeout(command)

        output = String.new
        output << stdout unless stdout.empty?
        output << "\nSTDERR:\n#{stderr}" unless stderr.empty?
        output << "\nExit code: #{status.exitstatus}"

        truncate_output(output)
      rescue Errno::ENOENT => e
        { error: "Command not found: #{e.message}" }
      rescue StandardError => e
        { error: "Command failed: #{e.message}" }
      end

      private

      def run_with_timeout(command)
        stdin, stdout_io, stderr_io, wait_thr = Open3.popen3(command, chdir: @project_root)
        stdin.close

        unless wait_thr.join(TIMEOUT_SECONDS)
          kill_process(wait_thr.pid)
          raise StandardError, "Command timed out after #{TIMEOUT_SECONDS} seconds"
        end

        [stdout_io.read, stderr_io.read, wait_thr.value]
      ensure
        [stdin, stdout_io, stderr_io].each { |io| io&.close unless io&.closed? }
      end

      def kill_process(pid)
        Process.kill("TERM", pid)
        sleep(0.5)
        Process.kill("KILL", pid) if process_alive?(pid)
      rescue Errno::ESRCH, Errno::EPERM
        # Process already exited or not accessible
      end

      def process_alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end

      def truncate_output(output)
        if output.length > MAX_OUTPUT_CHARS
          "#{output[0, MAX_OUTPUT_CHARS]}...(truncated, #{output.length} total characters)"
        else
          output
        end
      end
    end
  end
end
