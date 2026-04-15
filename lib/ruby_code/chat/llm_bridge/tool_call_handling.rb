# frozen_string_literal: true

module RubyCode
  module Chat
    class LLMBridge
      # Handles tool call lifecycle: invocation, confirmation, limits, and results.
      module ToolCallHandling
        private

        def configure_agentic!(chat)
          tools = @tool_registry.build_tools
          chat.with_tools(*tools, replace: true)
          chat.with_instructions(Tools::SystemPrompt.build(
                                   project_root: @project_root,
                                   max_write_rounds: MAX_WRITE_TOOL_ROUNDS,
                                   max_total_rounds: MAX_TOTAL_TOOL_ROUNDS
                                 ))

          chat.on_tool_call { |tool_call| handle_tool_call(tool_call) }
          chat.on_tool_result { |result| handle_tool_result(result) }
        end

        def handle_tool_call(tool_call)
          raise Tools::AgentCancelledError, "Operation cancelled by user" if @cancel_requested

          display_name = short_tool_name(tool_call.name)
          risk = @tool_registry.risk_level_for(tool_call.name)

          increment_call_counts(risk)
          check_tool_limits!
          warn_approaching_limit

          process_tool_approval(tool_call, display_name, risk)
        end

        def increment_call_counts(risk)
          @tool_call_count += 1
          @write_tool_call_count += 1 unless risk == Tools::BaseTool::SAFE_RISK
        end

        def process_tool_approval(tool_call, display_name, risk)
          args_summary = tool_call.arguments.map { |k, v| "#{k}: #{v}" }.join(", ")

          if risk == Tools::BaseTool::SAFE_RISK || @state.auto_approve_tools?
            @state.add_message(:tool_call, "[#{display_name}] #{args_summary}")
          else
            risk_label = risk == Tools::BaseTool::DANGEROUS_RISK ? "DANGEROUS" : "WRITE"
            @state.request_tool_confirmation!(display_name, tool_call.arguments, risk_label: risk_label)
            wait_for_confirmation(tool_call)
          end
        end

        def wait_for_confirmation(tool_call)
          display_name = short_tool_name(tool_call.name)
          decision = poll_tool_decision
          apply_tool_decision(decision, display_name)
        end

        def apply_tool_decision(decision, display_name)
          case decision
          when :cancelled
            @state.clear_tool_confirmation!
            raise Tools::AgentCancelledError, "Operation cancelled by user"
          when :approved
            @state.resolve_tool_confirmation!(:approved)
          when :rejected
            @state.resolve_tool_confirmation!(:rejected)
            raise RubyCode::Tools::ToolRejectedError, "User rejected #{display_name}"
          end
        end

        def poll_tool_decision
          @state.mutex.synchronize do
            loop do
              return :cancelled if @cancel_requested

              case @state.instance_variable_get(:@tool_confirmation_response)
              when :approved then return :approved
              when :rejected then return :rejected
              end

              @state.tool_cv.wait(@state.mutex, 0.1)
            end
          end
        end

        def handle_tool_result(result)
          text = result.to_s
          if text.length > MAX_TOOL_RESULT_CHARS
            text = "#{text[0, MAX_TOOL_RESULT_CHARS]}\n... (truncated, #{text.length} total characters)"
          end
          @state.add_message(:tool_result, text)
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
          warn_limit(@tool_call_count, MAX_TOTAL_TOOL_ROUNDS, "total")
        end

        def warn_limit(count, max, label)
          warning_at = (max * TOOL_ROUNDS_WARNING_THRESHOLD).to_i
          return unless count == warning_at

          remaining = max - count
          @state.add_message(:system,
                             "Approaching #{label} tool call limit: #{remaining} calls remaining. " \
                             "Prioritize completing the most important work.")
        end

        def short_tool_name(name)
          name.split("--").last
        end
      end
    end
  end
end
