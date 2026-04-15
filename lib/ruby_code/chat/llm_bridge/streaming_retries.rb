# frozen_string_literal: true

module RubyCode
  module Chat
    class LLMBridge
      # Manages streaming responses, retry logic, and error recovery.
      module StreamingRetries
        private

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
            output_tokens: response.output_tokens,
            thinking_tokens: response.respond_to?(:thinking_tokens) ? response.thinking_tokens : nil,
            cached_tokens: response.respond_to?(:cached_tokens) ? response.cached_tokens : nil,
            cache_creation_tokens: response.respond_to?(:cache_creation_tokens) ? response.cache_creation_tokens : nil
          )
        end

        def attempt_with_retries(chat, input, retries = 0)
          stream_response(chat, input, retries)
        rescue Tools::AgentCancelledError, Tools::AgentIterationLimitError, RubyCode::Tools::ToolRejectedError => e
          @state.add_message(:system, e.message)
          nil
        rescue RubyLLM::RateLimitError => e
          retry if (retries = handle_rate_limit_retry(e, retries))
          handle_api_failure(e, rate_limit_user_message(e))
        rescue StandardError => e
          handle_api_failure(e, generic_api_error_message(e))
        end

        def handle_api_failure(error, message)
          @state.fail_last_assistant(error, friendly_message: message)
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
      end
    end
  end
end
