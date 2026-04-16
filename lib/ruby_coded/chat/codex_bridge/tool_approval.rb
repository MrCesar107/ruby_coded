# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Manages interactive approval flow for tool calls in agentic mode.
      module ToolApproval
        private

        def request_approval(_tool_call, display_name, args, risk)
          args_summary = args.map { |k, v| "#{k}: #{v}" }.join(", ")

          if risk == Tools::BaseTool::SAFE_RISK || @state.auto_approve_tools?
            @state.add_message(:tool_call, "[#{display_name}] #{args_summary}")
          else
            risk_label = risk == Tools::BaseTool::DANGEROUS_RISK ? "DANGEROUS" : "WRITE"
            @state.request_tool_confirmation!(display_name, args, risk_label: risk_label)
            decision = poll_tool_decision
            apply_tool_decision(decision, display_name)
          end
        end

        def poll_tool_decision
          @state.mutex.synchronize do
            loop do
              return :cancelled if @cancel_requested

              resp = @state.instance_variable_get(:@tool_confirmation_response)
              return resp if %i[approved rejected].include?(resp)

              @state.tool_cv.wait(@state.mutex, 0.1)
            end
          end
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
            raise Tools::ToolRejectedError, "User rejected #{display_name}"
          end
        end
      end
    end
  end
end
