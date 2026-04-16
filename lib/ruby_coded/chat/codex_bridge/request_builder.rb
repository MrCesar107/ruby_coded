# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Builds HTTP requests for the Codex Responses API.
      module RequestBuilder
        CODEX_HEADERS_BASE = {
          "Content-Type" => "application/json",
          "Accept" => "text/event-stream",
          "originator" => "codex_cli_rs",
          "OpenAI-Beta" => "responses=experimental"
        }.freeze

        DEFAULT_INSTRUCTIONS = "You are a helpful coding assistant. " \
                               "Answer concisely and provide code examples when relevant."

        private

        def codex_headers
          credentials = current_credentials
          account_id = Auth::JWTDecoder.extract_account_id(credentials["access_token"])

          CODEX_HEADERS_BASE.merge(
            "Authorization" => "Bearer #{credentials["access_token"]}",
            "chatgpt-account-id" => account_id.to_s
          )
        end

        def build_request_body
          body = base_request_body
          body[:tools] = build_tools_spec if @agentic_mode || @plan_mode
          body
        end

        def base_request_body
          {
            model: @model, instructions: build_instructions,
            input: build_input_array, store: false, stream: true,
            reasoning: { effort: "medium", summary: "auto" },
            text: { verbosity: "medium" },
            include: ["reasoning.encrypted_content"]
          }
        end

        def build_input_array
          @conversation_history.map { |msg| format_history_message(msg) }
        end

        def format_history_message(msg)
          case msg[:type]
          when "function_call" then format_function_call(msg)
          when "function_call_output" then format_function_output(msg)
          else { role: msg[:role], content: msg[:content].to_s }
          end
        end

        def format_function_call(msg)
          {
            type: "function_call", name: msg[:name],
            arguments: msg[:arguments].is_a?(String) ? msg[:arguments] : msg[:arguments].to_json,
            call_id: msg[:call_id]
          }
        end

        def format_function_output(msg)
          { type: "function_call_output", call_id: msg[:call_id], output: msg[:output].to_s }
        end

        def build_instructions
          if @agentic_mode
            Tools::SystemPrompt.build(
              project_root: @project_root, max_write_rounds: MAX_WRITE_TOOL_ROUNDS,
              max_total_rounds: MAX_TOTAL_TOOL_ROUNDS
            )
          elsif @plan_mode
            Tools::PlanSystemPrompt.build(project_root: @project_root)
          else
            DEFAULT_INSTRUCTIONS
          end
        end

        def build_tools_spec
          tool_instances = if @agentic_mode
                             @tool_registry.build_tools
                           else
                             @tool_registry.build_readonly_tools
                           end

          tool_instances.map { |tool| tool_to_responses_api(tool) }
        end

        def tool_to_responses_api(tool)
          {
            type: "function",
            name: tool.name,
            description: tool.description.to_s,
            parameters: tool.params_schema
          }
        end
      end
    end
  end
end
