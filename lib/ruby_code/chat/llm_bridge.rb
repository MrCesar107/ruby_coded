# frozen_string_literal: true

require "ruby_llm"
require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/agent_cancelled_error"
require_relative "../tools/agent_iteration_limit_error"
require_relative "plan_clarification_parser"
require_relative "llm_bridge/tool_call_handling"
require_relative "llm_bridge/streaming_retries"
require_relative "llm_bridge/plan_mode"

module RubyCode
  module Chat
    # Sends prompts to RubyLLM and streams assistant output into State.
    class LLMBridge
      include ToolCallHandling
      include StreamingRetries
      include PlanMode

      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2
      MAX_WRITE_TOOL_ROUNDS = 50
      MAX_TOTAL_TOOL_ROUNDS = 200
      TOOL_ROUNDS_WARNING_THRESHOLD = 0.8
      MAX_TOOL_RESULT_CHARS = 10_000

      attr_reader :agentic_mode, :plan_mode, :project_root

      def initialize(state, project_root: Dir.pwd)
        @state = state
        @chat_mutex = Mutex.new
        @cancel_requested = false
        @project_root = project_root
        @agentic_mode = false
        @plan_mode = false
        @tool_registry = Tools::Registry.new(project_root: @project_root)
        reset_chat!(@state.model)
      end

      def reset_chat!(model_name)
        @chat_mutex.synchronize do
          @chat = RubyLLM.chat(model: model_name)
          apply_mode_config!(@chat)
        end
      end

      def toggle_agentic_mode!(enabled)
        @agentic_mode = enabled
        if enabled && @plan_mode
          @plan_mode = false
          @state.deactivate_plan_mode!
        end
        @state.disable_auto_approve! unless enabled
        reconfigure_chat!
      end

      def reset_agent_session!
        @tool_call_count = 0
        @write_tool_call_count = 0
        reset_chat!(@state.model)
      end

      def toggle_plan_mode!(enabled)
        @plan_mode = enabled
        if enabled && @agentic_mode
          @agentic_mode = false
          @state.disable_auto_approve!
        end
        reconfigure_chat!
      end

      def send_async(input)
        auto_switch_to_agent! if should_auto_switch_to_agent?(input)
        reset_call_counts
        chat = prepare_streaming
        Thread.new do
          response = attempt_with_retries(chat, input)
          update_response_tokens(response)
          post_process_plan_response if @plan_mode && !@cancel_requested
        ensure
          @state.streaming = false
        end
      end

      def cancel!
        @cancel_requested = true
        @state.mutex.synchronize { @state.tool_cv.signal }
      end

      def approve_tool!
        @state.tool_confirmation_response = :approved
      end

      def approve_all_tools!
        @state.enable_auto_approve!
        @state.tool_confirmation_response = :approved
      end

      def reject_tool!
        @state.tool_confirmation_response = :rejected
      end

      private

      def reset_call_counts
        @tool_call_count = 0
        @write_tool_call_count = 0
      end

      def reconfigure_chat!
        @chat_mutex.synchronize do
          apply_mode_config!(@chat)
        end
      end

      def apply_mode_config!(chat)
        if @agentic_mode
          configure_agentic!(chat)
        elsif @plan_mode
          configure_plan!(chat)
        else
          chat.with_tools(replace: true)
        end
      end
    end
  end
end
