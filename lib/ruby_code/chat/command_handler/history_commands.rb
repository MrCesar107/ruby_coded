# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # Slash commands for viewing conversation history.
      module HistoryCommands
        private

        def cmd_history(_rest)
          conv = conversation_messages
          if conv.empty?
            @state.add_message(:system, "No conversation history yet.")
            return
          end

          @state.add_message(:system, format_history(conv))
        end

        def conversation_messages
          @state.messages_snapshot.reject { |m| m[:role] == :system }
        end

        def format_history(conv)
          lines = conv.map.with_index(1) { |msg, i| format_history_line(msg, i) }
          "Conversation history (#{conv.size} messages):\n#{lines.join("\n")}"
        end

        def format_history_line(msg, index)
          role = msg[:role].to_s.capitalize
          preview = msg[:content].to_s.lines.first&.strip || ""
          preview = "#{preview[0..60]}..." if preview.length > 60
          "  #{index}. [#{role}] #{preview}"
        end
      end
    end
  end
end
