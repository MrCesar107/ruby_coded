# frozen_string_literal: true

require_relative "tool_approval"

module RubyCoded
  module Chat
    class CodexBridge
      # Handles tool call execution, confirmation, and the multi-turn loop
      # for agentic mode over the Codex Responses API.
      module ToolHandling
        include ToolApproval

        private

        def process_pending_tool_calls(pending_tool_calls, _original_input)
          pending_tool_calls.each do |tool_call|
            break if @cancel_requested

            execute_tool_call(tool_call)
          end

          return if @cancel_requested

          @state.add_message(:assistant, "")
          continue_after_tools
        end

        def execute_tool_call(tool_call)
          name = tool_call[:name]
          args = parse_tool_arguments(tool_call[:arguments])
          display_name = short_tool_name(name)
          risk = @tool_registry.risk_level_for(name)

          increment_call_counts(risk)
          check_tool_limits!
          warn_approaching_limit

          request_approval(tool_call, display_name, args, risk)
          result = run_tool(name, args)
          record_tool_result(tool_call, result)
        end

        def parse_tool_arguments(args_str)
          return args_str if args_str.is_a?(Hash)

          JSON.parse(args_str)
        rescue JSON::ParserError
          {}
        end

        def run_tool(name, args)
          tool_instances = @agentic_mode ? @tool_registry.build_tools : @tool_registry.build_readonly_tools
          tool = tool_instances.find { |t| tool_name_match?(t, name) }

          return { error: "Unknown tool: #{name}" } unless tool

          symbolized = args.transform_keys(&:to_sym)
          tool.execute(**symbolized)
        rescue StandardError => e
          { error: e.message }
        end

        def tool_name_match?(tool, name)
          tool.name == name || tool.name.split("--").last == name.split("--").last
        end

        def record_tool_result(tool_call, result)
          @state.add_message(:tool_result, truncate_result(result))
          record_tool_call_history(tool_call, result)
        end

        def truncate_result(result)
          text = result.to_s
          return text if text.length <= MAX_TOOL_RESULT_CHARS

          "#{text[0, MAX_TOOL_RESULT_CHARS]}\n... (truncated, #{text.length} total characters)"
        end

        def record_tool_call_history(tool_call, result)
          @conversation_history << {
            type: "function_call", call_id: tool_call[:call_id],
            name: tool_call[:name], arguments: tool_call[:arguments]
          }
          @conversation_history << {
            type: "function_call_output", call_id: tool_call[:call_id], output: result.to_s
          }
        end

        def continue_after_tools
          perform_codex_request(nil)
        end

        def increment_call_counts(risk)
          @tool_call_count += 1
          @write_tool_call_count += 1 unless risk == Tools::BaseTool::SAFE_RISK
        end

        def check_tool_limits!
          if @write_tool_call_count >= MAX_WRITE_TOOL_ROUNDS
            @write_tool_call_count = 0
            @state.add_message(:system,
                               "Write tool call budget (#{MAX_WRITE_TOOL_ROUNDS}) reached — auto-resetting counter.")
          end

          return unless @tool_call_count > MAX_TOTAL_TOOL_ROUNDS

          raise Tools::AgentIterationLimitError,
                "Reached maximum of #{MAX_TOTAL_TOOL_ROUNDS} total tool calls. " \
                "Send a new message to continue, or use /agent on to reset counters."
        end

        def warn_approaching_limit
          threshold = (MAX_TOTAL_TOOL_ROUNDS * TOOL_ROUNDS_WARNING_THRESHOLD).to_i
          return unless @tool_call_count == threshold

          remaining = MAX_TOTAL_TOOL_ROUNDS - threshold
          @state.add_message(:system,
                             "Approaching total tool call limit: #{remaining} calls remaining. " \
                             "Prioritize completing the most important work.")
        end

        def short_tool_name(name)
          name.split("--").last
        end
      end
    end
  end
end
