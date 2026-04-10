# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # Manages the tool confirmation flow as inline chat messages.
      # When a destructive tool is requested, a :tool_pending message
      # is added to the conversation; the user approves or rejects
      # via keyboard, and the message is updated in place.
      #
      # The user can press [a] to approve all future tool calls for
      # the current session, bypassing individual confirmations.
      module ToolConfirmation
        attr_reader :tool_cv

        def init_tool_confirmation
          @pending_tool_name = nil
          @pending_tool_args = nil
          @tool_confirmation_response = nil
          @auto_approve_tools = false
          @tool_cv = ConditionVariable.new
        end

        def awaiting_tool_confirmation?
          @mode == :tool_confirmation
        end

        def auto_approve_tools?
          @auto_approve_tools
        end

        def enable_auto_approve!
          @auto_approve_tools = true
        end

        def disable_auto_approve!
          @auto_approve_tools = false
        end

        def pending_tool_name
          @pending_tool_name
        end

        def pending_tool_args
          @pending_tool_args
        end

        def tool_confirmation_response
          @mutex.synchronize { @tool_confirmation_response }
        end

        def tool_confirmation_response=(value)
          @mutex.synchronize do
            @tool_confirmation_response = value
            @tool_cv.signal
          end
        end

        def request_tool_confirmation!(tool_name, tool_args, risk_label: "WRITE")
          args_text = tool_args.map { |k, v| "#{k}: #{v}" }.join(", ")
          pending_text = "[#{risk_label}] #{tool_name}(#{args_text}) — [y] approve / [n] reject / [a] approve all"

          @mutex.synchronize do
            @pending_tool_name = tool_name
            @pending_tool_args = tool_args
            @tool_confirmation_response = nil
            @mode = :tool_confirmation
            @messages << {
              role: :tool_pending,
              content: String.new(pending_text),
              timestamp: Time.now,
              input_tokens: 0,
              output_tokens: 0
            }
            @message_generation += 1
            @dirty = true
          end

          scroll_to_bottom
        end

        def resolve_tool_confirmation!(decision)
          @mutex.synchronize do
            last_pending = @messages.reverse.find { |m| m[:role] == :tool_pending }
            if last_pending
              label = decision == :approved ? "approved" : "rejected"
              last_pending[:role] = :tool_call
              last_pending[:content] = last_pending[:content].sub(/ — \[y\].*/, " — #{label}")
            end

            @pending_tool_name = nil
            @pending_tool_args = nil
            @tool_confirmation_response = nil
            @mode = :chat
            @message_generation += 1
            @dirty = true
          end
        end

        def clear_tool_confirmation!
          @mutex.synchronize do
            @pending_tool_name = nil
            @pending_tool_args = nil
            @tool_confirmation_response = nil
            @mode = :chat
            @dirty = true
          end
        end
      end
    end
  end
end
