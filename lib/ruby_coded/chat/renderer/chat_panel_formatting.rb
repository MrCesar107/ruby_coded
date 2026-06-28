# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Message-to-text formatting helpers used by the chat panel.
      module ChatPanelFormatting
        USER_LABEL = "YOU"

        private

        def format_messages_text(messages)
          messages.filter_map { |m| format_message(m) }.join("\n")
        end

        def format_message(msg)
          case msg[:role]
          when :tool_call, :tool_pending, :tool_result then nil
          when :system    then "--- #{msg[:content]}"
          when :user      then format_user_message(msg[:content])
          when :assistant then format_assistant_message(msg[:content])
          else                 "#{msg[:role]}: #{msg[:content]}"
          end
        end

        def format_user_message(content)
          "[#{USER_LABEL}] #{content}"
        end

        def format_assistant_message(content)
          result = strip_think_tags(content)
          result.empty? ? nil : result
        end
      end
    end
  end
end
