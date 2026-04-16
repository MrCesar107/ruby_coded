# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Parses Server-Sent Events from the Codex streaming response and
      # dispatches content deltas, tool calls, and completion signals.
      module SSEParser
        StreamContext = Struct.new(
          :assistant_text, :pending_tool_calls, :buffer, :raw_body, :status, keyword_init: true
        )

        private

        def perform_codex_request(input)
          ensure_token_fresh!
          ctx = StreamContext.new(assistant_text: +"", pending_tool_calls: [], buffer: +"", raw_body: +"", status: nil)
          execute_streaming_post(ctx)
          finalize_response(ctx.assistant_text)
          process_pending_tool_calls(ctx.pending_tool_calls, input) if ctx.pending_tool_calls.any?
        end

        def execute_streaming_post(ctx)
          response = post_streaming_request(ctx)
          ctx.status ||= response.status
          handle_http_error(ctx.status, ctx.raw_body) unless (200..299).cover?(ctx.status)
        end

        def post_streaming_request(ctx)
          @conn.post(CODEX_RESPONSES_PATH) do |req|
            req.headers = codex_headers
            req.body = build_request_body.to_json
            req.options.on_data = proc { |chunk, _size, env| handle_stream_chunk(ctx, chunk, env) }
          end
        end

        def handle_stream_chunk(ctx, chunk, env)
          ctx.status ||= env&.status
          ctx.raw_body << chunk
          return if @cancel_requested || (ctx.status && !(200..299).cover?(ctx.status))

          ctx.buffer << chunk
          process_sse_buffer(ctx.buffer, ctx.assistant_text, ctx.pending_tool_calls)
        end

        def process_sse_buffer(buffer, assistant_text, pending_tool_calls)
          while (line_end = buffer.index("\n"))
            line = buffer.slice!(0, line_end + 1).strip
            next if line.empty?

            process_sse_line(line, assistant_text, pending_tool_calls)
          end
        end

        def process_sse_line(line, assistant_text, pending_tool_calls)
          return unless line.start_with?("data: ")

          data = line[6..]
          return if data == "[DONE]"

          event = parse_json(data)
          return unless event

          dispatch_sse_event(event, assistant_text, pending_tool_calls)
        end

        def dispatch_sse_event(event, assistant_text, pending_tool_calls)
          case event["type"]
          when "response.output_text.delta" then handle_text_delta(event, assistant_text)
          when "response.function_call_arguments.delta" then handle_function_args_delta(event, pending_tool_calls)
          when "response.function_call_arguments.done" then handle_function_call_done(event, pending_tool_calls)
          when "response.output_item.added" then handle_output_item_added(event, pending_tool_calls)
          end
        end

        def handle_text_delta(event, assistant_text)
          delta = event["delta"]
          return unless delta.is_a?(String) && !delta.empty?

          assistant_text << delta
          @state.streaming_append(delta)
        end

        def handle_output_item_added(event, pending_tool_calls)
          item = event["item"]
          return unless item && item["type"] == "function_call"

          pending_tool_calls << {
            call_id: item["call_id"] || item["id"],
            name: item["name"],
            arguments: +""
          }
        end

        def handle_function_args_delta(event, pending_tool_calls)
          delta = event["delta"]
          return unless delta.is_a?(String)

          pending_tool_calls.last&.tap { |c| c[:arguments] << delta }
        end

        def handle_function_call_done(event, pending_tool_calls)
          call_id = event["call_id"] || event.dig("item", "call_id")
          return unless call_id

          tc = pending_tool_calls.find { |c| c[:call_id] == call_id }
          tc[:arguments] = event["arguments"] || tc[:arguments] if tc
        end

        def finalize_response(assistant_text)
          @conversation_history << { role: "assistant", content: assistant_text } unless assistant_text.empty?
        end

        def handle_http_error(status, body_text)
          detail = extract_error_detail(body_text)
          raise CodexAPIError.new(status, detail)
        end

        def extract_error_detail(body_text)
          parsed = JSON.parse(body_text)
          return body_text[0, 300] unless parsed.is_a?(Hash)

          parsed.dig("error", "message") || parsed["detail"] || parsed["message"] || body_text[0, 300]
        rescue StandardError
          body_text[0, 300]
        end

        def parse_json(str)
          JSON.parse(str)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
