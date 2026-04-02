# frozen_string_literal: true

require "ruby_llm"

module RubyCode
  module Chat
    # Sends prompts to RubyLLM and streams assistant output into State.
    class LLMBridge
      def initialize(state)
        @state = state
        @chat_mutex = Mutex.new
        @cancel_requested = false
        reset_chat!(@state.model)
      end

      def reset_chat!(model_name)
        @chat_mutex.synchronize do
          @chat = RubyLLM.chat(model: model_name)
        end
      end

      def send_async(input)
        @cancel_requested = false
        @state.streaming = true
        @state.add_message(:assistant, "")

        chat = @chat_mutex.synchronize { @chat }

        Thread.new do
          begin
            response = nil

            begin
              response = chat.ask(input) do |chunk|
                break if @cancel_requested

                @state.append_to_last_message(chunk.content) if chunk.content
              end
            rescue RubyLLM::RateLimitError => e
              # Do not retry here: ruby_llm's Faraday layer used to retry 429s up to
              # config.max_retries (we set that to 0 in AuthManager#configure_ruby_llm!).
              @state.fail_last_assistant(e, friendly_message: rate_limit_user_message(e))
              response = nil
            rescue StandardError => e
              @state.fail_last_assistant(e, friendly_message: generic_api_error_message(e))
              response = nil
            end

            if response && !@cancel_requested && response.respond_to?(:input_tokens)
              @state.update_last_message_tokens(
                input_tokens: response.input_tokens,
                output_tokens: response.output_tokens
              )
            end
          ensure
            @state.streaming = false
          end
        end
      end

      def cancel!
        @cancel_requested = true
      end

      private

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
