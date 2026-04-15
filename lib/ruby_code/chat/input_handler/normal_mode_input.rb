# frozen_string_literal: true

module RubyCode
  module Chat
    class InputHandler
      # Handles input events for normal chat mode:
      # text editing, cursor movement, scrolling, paste, and plugin dispatch.
      module NormalModeInput
        private

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
          scroll = detect_scroll(event)
          return scroll if scroll
          return move_cursor_left if event.left?
          return move_cursor_right if event.right?
          return move_cursor_home if event.home?
          return move_cursor_end if event.end?

          append_character(event)
        end

        def detect_scroll(event)
          return :scroll_up if event.up? || event.page_up?

          :scroll_down if event.down? || event.page_down?
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

        def move_cursor_left
          @state.move_cursor_left
          nil
        end

        def move_cursor_right
          @state.move_cursor_right
          nil
        end

        def move_cursor_home
          @state.move_cursor_to_start
          nil
        end

        def move_cursor_end
          @state.move_cursor_to_end
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
end
