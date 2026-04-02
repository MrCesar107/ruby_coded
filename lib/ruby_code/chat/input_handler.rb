# frozen_string_literal: true

require "ratatui_ruby"

module RubyCode
  module Chat
    # This class is used to handle the input events for the chat
    class InputHandler
      def initialize(state)
        @state = state
      end

      def process(event)
        return handle_paste(event) if event.is_a?(RatatuiRuby::Event::Paste)
        return nil unless event.key?

        if @state.streaming?
          handle_streaming_mode(event)
        else
          handle_normal_mode(event)
        end
      end

      private

      def handle_streaming_mode(event)
        return :quit if event.ctrl_c?
        return :cancel_streaming if event.esc?

        nil
      end

      def handle_normal_mode(event)
        return :quit if event.ctrl_c?
        return submit if event.enter?
        return backspace if event.backspace?
        return clear_input if event.esc?
        return :scroll_up if event.up? || event.page_up?
        return :scroll_down if event.down? || event.page_down?
        return :scroll_top if event.home?
        return :scroll_bottom if event.end?

        append_character(event)
      end

      def submit
        return nil if @state.input_buffer.strip.empty?

        :submit
      end

      def backspace
        @state.delete_last_char
        nil
      end

      def clear_input
        @state.clear_input!
        nil
      end

      def append_character(event)
        char = event.to_s
        return nil if char.empty?
        return nil if event.ctrl? || event.alt?

        @state.append_to_input(char)
        nil
      end

      def handle_paste(event)
        text = event.content.tr("\n", " ")
        @state.append_to_input(text) unless text.empty?
        nil
      end
    end
  end
end
