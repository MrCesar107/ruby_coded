# frozen_string_literal: true

require "faraday"
require "json"
require "time"

require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/agent_cancelled_error"
require_relative "../tools/agent_iteration_limit_error"
require_relative "../auth/jwt_decoder"
require_relative "codex_bridge/request_builder"
require_relative "codex_bridge/sse_parser"
require_relative "codex_bridge/tool_handling"
require_relative "codex_bridge/token_manager"
require_relative "codex_bridge/error_handling"

module RubyCoded
  module Chat
    # Raised when the Codex HTTP API returns a non-2xx response.
    class CodexAPIError < StandardError
      attr_reader :status

      def initialize(status, detail)
        @status = status
        super("HTTP #{status}: #{detail}")
      end
    end

    # HTTP client for the ChatGPT Codex backend (Responses API).
    # Implements the same public interface as LLMBridge so App can
    # swap between them based on the active auth_method.
    class CodexBridge
      include RequestBuilder
      include SSEParser
      include ToolHandling
      include TokenManager
      include ErrorHandling

      CODEX_BASE_URL = "https://chatgpt.com"
      CODEX_RESPONSES_PATH = "/backend-api/codex/responses"
      DEFAULT_MODEL = "gpt-5.4"

      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2
      MAX_WRITE_TOOL_ROUNDS = 50
      MAX_TOTAL_TOOL_ROUNDS = 200
      TOOL_ROUNDS_WARNING_THRESHOLD = 0.8
      MAX_TOOL_RESULT_CHARS = 10_000

      attr_reader :agentic_mode, :plan_mode, :project_root

      def initialize(state, credentials_store:, auth_manager:, project_root: Dir.pwd)
        @state = state
        @credentials_store = credentials_store
        @auth_manager = auth_manager
        @project_root = project_root
        @cancel_requested = @agentic_mode = @plan_mode = false
        @model = state.model
        @conversation_history = []
        @tool_registry = Tools::Registry.new(project_root: @project_root)
        reset_call_counts
        @conn = build_connection
      end

      def send_async(input)
        prepare_send(input)
        @conversation_history << { role: "user", content: input }
        Thread.new do
          attempt_with_retries(input)
        ensure
          @state.streaming = false
        end
      end

      def cancel!
        @cancel_requested = true
        @state.mutex.synchronize { @state.tool_cv.signal }
      end

      def reset_chat!(model_name)
        @model = model_name
        @conversation_history = []
      end

      def toggle_agentic_mode!(enabled)
        @agentic_mode = enabled
        @state.agentic_mode = enabled
        if enabled && @plan_mode
          @plan_mode = false
          @state.deactivate_plan_mode!
        end
        @state.disable_auto_approve! unless enabled
      end

      def toggle_plan_mode!(enabled)
        @plan_mode = enabled
        return unless enabled && @agentic_mode

        @agentic_mode = false
        @state.agentic_mode = false
        @state.disable_auto_approve!
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

      def reset_agent_session!
        @tool_call_count = 0
        @write_tool_call_count = 0
        @conversation_history = []
      end
    end
  end
end
