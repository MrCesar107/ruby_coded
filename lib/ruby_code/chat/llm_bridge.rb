# frozen_string_literal: true

require "ruby_llm"
require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/agent_cancelled_error"
require_relative "../tools/agent_iteration_limit_error"
require_relative "plan_clarification_parser"

module RubyCode
  module Chat
    # Sends prompts to RubyLLM and streams assistant output into State.
    class LLMBridge
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
        @tool_call_count = 0
        @write_tool_call_count = 0
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

      def configure_agentic!(chat)
        tools = @tool_registry.build_tools
        chat.with_tools(*tools, replace: true)
        chat.with_instructions(Tools::SystemPrompt.build(
                                 project_root: @project_root,
                                 max_write_rounds: MAX_WRITE_TOOL_ROUNDS,
                                 max_total_rounds: MAX_TOTAL_TOOL_ROUNDS
                               ))

        chat.on_tool_call do |tool_call|
          handle_tool_call(tool_call)
        end

        chat.on_tool_result do |result|
          handle_tool_result(result)
        end
      end

      def handle_tool_call(tool_call)
        raise Tools::AgentCancelledError, "Operation cancelled by user" if @cancel_requested

        display_name = short_tool_name(tool_call.name)
        risk = @tool_registry.risk_level_for(tool_call.name)

        @tool_call_count += 1
        @write_tool_call_count += 1 unless risk == Tools::BaseTool::SAFE_RISK
        check_tool_limits!
        warn_approaching_limit

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

      # "ruby_code--tools--read_file_tool" → "read_file_tool"
      def short_tool_name(name)
        name.split("--").last
      end

      def prepare_streaming
        @cancel_requested = false
        @state.streaming = true
        @state.add_message(:assistant, "")
        @chat_mutex.synchronize { @chat }
      end

      def update_response_tokens(response)
        return unless response && !@cancel_requested && response.respond_to?(:input_tokens)

        @state.update_last_message_tokens(
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens
        )
      end

      def attempt_with_retries(chat, input, retries = 0)
        stream_response(chat, input, retries)
      rescue Tools::AgentCancelledError => e
        @state.add_message(:system, e.message)
        nil
      rescue Tools::AgentIterationLimitError => e
        @state.add_message(:system, e.message)
        nil
      rescue RubyCode::Tools::ToolRejectedError => e
        @state.add_message(:system, e.message)
        nil
      rescue RubyLLM::RateLimitError => e
        retries = handle_rate_limit_retry(e, retries)
        retry if retries
        @state.fail_last_assistant(e, friendly_message: rate_limit_user_message(e))
        nil
      rescue StandardError => e
        @state.fail_last_assistant(e, friendly_message: generic_api_error_message(e))
        nil
      end

      def stream_response(chat, input, retries)
        block = streaming_block
        retries.zero? ? chat.ask(input, &block) : chat.complete(&block)
      end

      def streaming_block
        proc do |chunk|
          break if @cancel_requested

          @state.streaming_append(chunk.content) if chunk.content
        end
      end

      def handle_rate_limit_retry(error, retries)
        return unless retries < MAX_RATE_LIMIT_RETRIES && !@cancel_requested

        retries += 1
        delay = RATE_LIMIT_BASE_DELAY * (2**(retries - 1))
        @state.fail_last_assistant(
          error,
          friendly_message: "Rate limit alcanzado. Reintentando en #{delay}s... (#{retries}/#{MAX_RATE_LIMIT_RETRIES})"
        )
        sleep(delay)
        @state.reset_last_assistant_content
        retries
      end

      def rate_limit_user_message(error)
        <<~MSG.strip
          Límite de peticiones del proveedor (rate limit). Espera un minuto y vuelve a intentar; si se repite, revisa cuotas y plan en la consola de tu API (OpenAI, Anthropic, etc.).
          Detalle: #{error.message}
        MSG
      end

      def generic_api_error_message(error)
        "No se pudo obtener respuesta del modelo: #{error.message}"
      end

      def configure_plan!(chat)
        readonly_tools = @tool_registry.build_readonly_tools
        chat.with_tools(*readonly_tools, replace: true)
        chat.with_instructions(Tools::PlanSystemPrompt.build(project_root: @project_root))

        chat.on_tool_call do |tool_call|
          handle_tool_call(tool_call)
        end

        chat.on_tool_result do |result|
          handle_tool_result(result)
        end
      end

      def post_process_plan_response
        last_msg = @state.messages_snapshot.last
        return unless last_msg && last_msg[:role] == :assistant

        content = last_msg[:content]
        if PlanClarificationParser.clarification?(content)
          parsed = PlanClarificationParser.parse(content)
          return unless parsed

          stripped = PlanClarificationParser.strip_clarification(content)
          @state.reset_last_assistant_content
          @state.append_to_last_message(stripped) unless stripped.empty?
          @state.enter_plan_clarification!(parsed[:question], parsed[:options])
        else
          @state.update_current_plan!(content)
        end
      end
    end
  end
end
