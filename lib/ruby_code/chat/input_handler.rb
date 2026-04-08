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

        if @state.model_select?
          handle_model_select_mode(event)
        elsif @state.streaming?
          handle_streaming_mode(event)
        else
          handle_normal_mode(event)
        end
      end

      private

      def handle_model_select_mode(event)
        return :quit if event.ctrl_c?
        return :model_select_cancel if event.esc?
        return :model_selected if event.enter?

        handle_model_select_input(event)
        nil
      end

      def handle_model_select_input(event)
        if event.up?
          @state.model_select_up
        elsif event.down?
          @state.model_select_down
        elsif event.backspace?
          @state.delete_last_filter_char
        else
          append_filter_character(event)
        end
      end

      def handle_streaming_mode(event)
        return :quit if event.ctrl_c?
        return :cancel_streaming if event.esc?

        nil
      end

      def handle_normal_mode(event)
        return :quit if event.ctrl_c?

        plugin_action = try_plugin_inputs(event)
        return plugin_action if plugin_action

        return submit if event.enter?
        return backspace if event.backspace?
        return clear_input if event.esc?

        scroll_or_append(event)
      end

      # Runs each plugin's input handler in registration order.
      # Returns the first non-nil action, or nil if no plugin handled it.
      def try_plugin_inputs(event)
        RubyCode.plugin_registry.input_handler_configs.each do |config|
          result = send(config[:method], event)
          return result if result
        end
        nil
      end

      def scroll_or_append(event)
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

      def append_filter_character(event)
        char = event.to_s
        return if char.empty?
        return if event.ctrl? || event.alt?

        @state.append_to_model_filter(char)
      end

      def handle_paste(event)
        text = event.content.tr("\n", " ")
        if @state.model_select?
          @state.append_to_model_filter(text) unless text.empty?
        else
          @state.append_to_input(text) unless text.empty?
        end
        nil
      end
    end
  end
end
