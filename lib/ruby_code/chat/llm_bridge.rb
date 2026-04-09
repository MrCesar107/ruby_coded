# frozen_string_literal: true

require "ruby_llm"
require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "plan_clarification_parser"

module RubyCode
  module Chat
    # Sends prompts to RubyLLM and streams assistant output into State.
    class LLMBridge
      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2

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
          configure_agentic!(@chat) if @agentic_mode
          configure_plan!(@chat) if @plan_mode
        end
      end

      def toggle_agentic_mode!(enabled)
        @agentic_mode = enabled
        if enabled && @plan_mode
          @plan_mode = false
          @state.deactivate_plan_mode!
        end
        @state.disable_auto_approve! unless enabled
        reset_chat!(@state.model)
      end

      def toggle_plan_mode!(enabled)
        @plan_mode = enabled
        if enabled && @agentic_mode
          @agentic_mode = false
          @state.disable_auto_approve!
        end
        reset_chat!(@state.model)
      end

      def send_async(input)
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

      def configure_agentic!(chat)
        tools = @tool_registry.build_tools
        chat.with_tools(*tools)
        chat.with_instructions(Tools::SystemPrompt.build(project_root: @project_root))

        chat.on_tool_call do |tool_call|
          handle_tool_call(tool_call)
        end

        chat.on_tool_result do |result|
          handle_tool_result(result)
        end
      end

      def handle_tool_call(tool_call)
        display_name = short_tool_name(tool_call.name)
        risk = @tool_registry.risk_level_for(tool_call.name)
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
        loop do
          response = @state.tool_confirmation_response
          case response
          when :approved
            @state.resolve_tool_confirmation!(:approved)
            break
          when :rejected
            @state.resolve_tool_confirmation!(:rejected)
            raise RubyCode::Tools::ToolRejectedError, "User rejected #{display_name}"
          else
            sleep(0.1)
          end
          break if @cancel_requested
        end
      end

      def handle_tool_result(result)
        @state.add_message(:tool_result, result.to_s)
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

          if chunk.content
            @state.ensure_last_is_assistant!
            @state.append_to_last_message(chunk.content)
          end
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
        chat.with_instructions(Tools::PlanSystemPrompt.build(project_root: @project_root))
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
