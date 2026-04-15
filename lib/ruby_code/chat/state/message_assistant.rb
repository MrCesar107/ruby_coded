# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # Operations on the last assistant message: streaming, reset, and error handling.
      module MessageAssistant
        # Ensures the last message is :assistant so streaming chunks
        # land in the right place after tool call/result messages.
        def ensure_last_is_assistant!
          @mutex.synchronize do
            return if !@messages.empty? && @messages.last[:role] == :assistant

            @messages << build_message(:assistant)
            @message_generation += 1
            @dirty = true
          end
        end

        # Single-mutex operation combining ensure_last_is_assistant! + append.
        def streaming_append(text)
          @mutex.synchronize do
            @messages << build_message(:assistant) if @messages.empty? || @messages.last[:role] != :assistant
            @messages.last[:content] << text.to_s
            @message_generation += 1
            @dirty = true
          end
        end

        def last_assistant_empty?
          @mutex.synchronize do
            return true if @messages.empty?

            last = @messages.last
            last[:role] == :assistant && last[:content].strip.empty?
          end
        end

        def reset_last_assistant_content
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            return unless last[:role] == :assistant

            last[:content] = String.new
            @message_generation += 1
            @dirty = true
          end
        end

        def fail_last_assistant(error, friendly_message: nil)
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            return unless last[:role] == :assistant

            apply_error_to_message(last, friendly_message || "[Error] #{error.class}: #{error.message}")
            @message_generation += 1
            @dirty = true
          end
        end

        private

        def apply_error_to_message(message, err_line)
          if message[:content].strip.empty?
            message[:content] = String.new(err_line)
          else
            message[:content] << "\n\n#{err_line}"
          end
        end
      end
    end
  end
end
