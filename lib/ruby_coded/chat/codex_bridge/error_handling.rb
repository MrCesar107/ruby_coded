# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Retry logic and error message formatting for the Codex API client.
      module ErrorHandling
        AGENT_SWITCH_PATTERN = /
          \b(implement|go[ ]ahead|proceed|execut|ejecutar?|comenz|
          comienz|hazlo|constru[iy]|adelante|dale|do[ ]it|build[ ]it)\b
        /ix

        UNSUPPORTED_MODEL_PATTERN = /not supported when using Codex with a ChatGPT account/i

        private

        def build_connection
          Faraday.new(url: CODEX_BASE_URL) do |f|
            f.options.timeout = 300
            f.options.open_timeout = 30
          end
        end

        def reset_call_counts
          @tool_call_count = 0
          @write_tool_call_count = 0
        end

        def prepare_send(input)
          auto_switch_to_agent! if should_auto_switch_to_agent?(input)
          reset_call_counts
          @cancel_requested = false
          @state.streaming = true
          @state.add_message(:assistant, "")
        end

        def should_auto_switch_to_agent?(input)
          @plan_mode && @state.respond_to?(:current_plan) && @state.current_plan &&
            input.match?(AGENT_SWITCH_PATTERN)
        end

        def auto_switch_to_agent!
          toggle_agentic_mode!(true)
          @state.add_message(:system,
                             "Plan mode disabled — switching to agent mode to implement the plan.")
        end

        def attempt_with_retries(input, retries = 0, fallback_attempted = false)
          perform_codex_request(input)
        rescue Tools::AgentCancelledError, Tools::AgentIterationLimitError, Tools::ToolRejectedError => e
          @state.add_message(:system, e.message)
        rescue CodexAPIError => e
          if should_fallback_to_default_model?(e, fallback_attempted)
            switch_to_default_model!(e)
            fallback_attempted = true
            retry
          end
          @state.fail_last_assistant(e, friendly_message: codex_error_message(e))
        rescue Faraday::TooManyRequestsError => e
          retry if (retries = handle_rate_limit_retry(e, retries))
          @state.fail_last_assistant(e, friendly_message: rate_limit_message(e))
        rescue StandardError => e
          @state.fail_last_assistant(e, friendly_message: "Codex API error: #{e.message}")
        end

        def should_fallback_to_default_model?(error, already_attempted)
          return false if already_attempted
          return false unless error.status == 400
          return false unless error.message.match?(UNSUPPORTED_MODEL_PATTERN)

          @model != DEFAULT_MODEL
        end

        def switch_to_default_model!(error)
          previous_model = @model
          @model = DEFAULT_MODEL
          @state.model = DEFAULT_MODEL
          @state.reset_last_assistant_content
          @state.add_message(
            :system,
            "Model '#{previous_model}' requires ChatGPT Pro. " \
            "Falling back to #{DEFAULT_MODEL} and retrying. Detail: #{error.message}"
          )
        end

        def handle_rate_limit_retry(error, retries)
          return unless retries < MAX_RATE_LIMIT_RETRIES && !@cancel_requested

          retries += 1
          delay = RATE_LIMIT_BASE_DELAY * (2**(retries - 1))
          msg = "Rate limit reached. Retrying in #{delay}s... (#{retries}/#{MAX_RATE_LIMIT_RETRIES})"
          @state.fail_last_assistant(error, friendly_message: msg)
          sleep(delay)
          @state.reset_last_assistant_content
          retries
        end

        def codex_error_message(error)
          case error.status
          when 400
            if error.message.match?(UNSUPPORTED_MODEL_PATTERN)
              "The selected model requires ChatGPT Pro. " \
              "Use /model to pick one without the 'Pro only' tag. (#{error.message})"
            else
              "Codex API error: #{error.message}"
            end
          when 401
            "Authentication failed. Your OAuth session may have expired. " \
            "Try /login to re-authenticate. (#{error.message})"
          when 403
            "Access denied. Your ChatGPT subscription may not include Codex access. (#{error.message})"
          when 404 then "Codex endpoint not found. The API may have changed. (#{error.message})"
          when 429 then rate_limit_message(error)
          else "Codex API error: #{error.message}"
          end
        end

        def rate_limit_message(error)
          <<~MSG.strip
            ChatGPT usage limit reached. This may be a 5-hour or weekly limit on your Plus/Pro subscription.
            Wait and try again later. Detail: #{error.message}
          MSG
        end
      end
    end
  end
end
