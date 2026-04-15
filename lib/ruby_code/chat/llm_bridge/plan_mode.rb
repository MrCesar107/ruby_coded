# frozen_string_literal: true

module RubyCode
  module Chat
    class LLMBridge
      # Plan mode configuration, auto-switching to agent, and clarification handling.
      module PlanMode
        IMPLEMENTATION_PATTERNS = [
          /\bimplement/i,
          /\bgo ahead/i,
          /\bproceed/i,
          /\bexecut/i,
          /\bejecutar?/i,
          /\bcomenz/i,
          /\bcomienz/i,
          /\bhazlo/i,
          /\bconstru[iy]/i,
          /\badelante/i,
          /\bdale\b/i,
          /\bdo it/i,
          /\bbuild it/i
        ].freeze

        private

        def should_auto_switch_to_agent?(input)
          @plan_mode && @state.current_plan && implementation_request?(input)
        end

        def implementation_request?(input)
          IMPLEMENTATION_PATTERNS.any? { |pattern| input.match?(pattern) }
        end

        def auto_switch_to_agent!
          toggle_agentic_mode!(true)
          @state.add_message(:system,
                             "Plan mode disabled — switching to agent mode to implement the plan.")
        end

        def configure_plan!(chat)
          readonly_tools = @tool_registry.build_readonly_tools
          chat.with_tools(*readonly_tools, replace: true)
          chat.with_instructions(Tools::PlanSystemPrompt.build(project_root: @project_root))

          chat.on_tool_call { |tool_call| handle_tool_call(tool_call) }
          chat.on_tool_result { |result| handle_tool_result(result) }
        end

        def post_process_plan_response
          last_msg = @state.messages_snapshot.last
          return unless last_msg && last_msg[:role] == :assistant

          content = last_msg[:content]
          if PlanClarificationParser.clarification?(content)
            handle_plan_clarification(content)
          else
            @state.update_current_plan!(content)
          end
        end

        def handle_plan_clarification(content)
          parsed = PlanClarificationParser.parse(content)
          return unless parsed

          stripped = PlanClarificationParser.strip_clarification(content)
          @state.reset_last_assistant_content
          @state.append_to_last_message(stripped) unless stripped.empty?
          @state.enter_plan_clarification!(parsed[:question], parsed[:options])
        end
      end
    end
  end
end
