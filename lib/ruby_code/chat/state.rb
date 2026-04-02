# frozen_string_literal: true

module RubyCode
  module Chat
    # This class is used to manage the state of the chat
    class State
      attr_reader :input_buffer, :messages, :scroll_offset
      attr_accessor :model, :streaming, :should_quit

      def initialize(model:)
        @model = model
        # String.new: literals like "" are frozen under frozen_string_literal
        @input_buffer = String.new
        @messages = []
        @streaming = false
        @should_quit = false
        @mutex = Mutex.new
      end

      def streaming?
        @streaming
      end

      def should_quit?
        @should_quit
      end

      def append_to_input(text)
        @input_buffer << text
      end

      def delete_last_char
        @input_buffer.chop!
      end

      def clear_input!
        @input_buffer.clear
      end

      def consume_input!
        input = @input_buffer.dup
        @input_buffer.clear
        input
      end

      def add_message(role, content)
        @mutex.synchronize do
          @messages << {
            role: role,
            content: String.new(content.to_s),
            timestamp: Time.now,
            input_tokens: 0,
            output_tokens: 0
          }
        end

        scroll_to_bottom
      end

      def append_to_last_message(text)
        @mutex.synchronize do
          return if @messages.empty?

          @messages.last[:content] << text.to_s
        end
      end

      def last_assistant_empty?
        @mutex.synchronize do
          return true if @messages.empty?

          last = @messages.last
          last[:role] == :assistant && last[:content].strip.empty?
        end
      end

      # friendly_message: user-friendly message to display to the user; if nil, the error message is used
      def fail_last_assistant(error, friendly_message: nil)
        @mutex.synchronize do
          return if @messages.empty?

          last = @messages.last
          return unless last[:role] == :assistant

          err_line = friendly_message || "[Error] #{error.class}: #{error.message}"
          if last[:content].strip.empty?
            last[:content] = String.new(err_line)
          else
            last[:content] << "\n\n#{err_line}"
          end
        end
      end

      def update_last_message_tokens(input_tokens:, output_tokens:)
        @mutex.synchronize do
          return if @messages.empty?

          @messages.last[:input_tokens] = input_tokens
          @messages.last[:output_tokens] = output_tokens
        end
      end

      def clear_messages!
        @mutex.synchronize { @messages.clear }
        @scroll_offset = 0
      end

      def scroll_up(amount = 1)
        @scroll_offset = [@scroll_offset + amount, max_scroll].min
      end

      def scroll_down(amount = 1)
        @scroll_offset = [@scroll_offset - amount, 0].max
      end

      def scroll_to_top
        @scroll_offset = max_scroll
      end

      def scroll_to_bottom
        @scroll_offset = 0
      end

      def total_input_tokens
        @mutex.synchronize do
          @messages.sum { |message| message[:input_tokens] }
        end
      end

      def total_output_tokens
        @mutex.synchronize do
          @messages.sum { |message| message[:output_tokens] }
        end
      end

      def messages_snapshot
        @mutex.synchronize { @messages.map(&:dup) }
      end

      private

      def max_scroll
        [@messages.length - 1, 0].max
      end
    end
  end
end
