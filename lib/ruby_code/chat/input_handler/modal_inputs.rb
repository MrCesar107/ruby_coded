# frozen_string_literal: true

module RubyCode
  module Chat
    class InputHandler
      # Handles input events for specialized UI modes:
      # tool confirmation, plan clarification, model selection, streaming, and mouse.
      module ModalInputs
        private

        def handle_tool_confirmation_mode(event)
          return :quit if event.ctrl_c?
          return :tool_rejected if event.esc?

          char = event.to_s.downcase
          return :tool_approved if event.enter? || char == "y"
          return :tool_rejected if char == "n"
          return :tool_approved_all if char == "a"

          nil
        end

        def handle_plan_clarification_mode(event)
          return :quit if event.ctrl_c?
          return :plan_clarification_skip if event.esc?
          return toggle_clarification_mode if event.tab?

          if @state.clarification_input_mode == :custom
            handle_clarification_custom_input(event)
          else
            handle_clarification_options_input(event)
          end
        end

        def handle_clarification_options_input(event)
          if event.up?
            @state.clarification_up
          elsif event.down?
            @state.clarification_down
          elsif event.enter?
            return :plan_clarification_selected
          end
          nil
        end

        def handle_clarification_custom_input(event)
          if event.enter?
            return :plan_clarification_custom unless @state.clarification_custom_input.strip.empty?
          elsif event.backspace?
            @state.delete_last_clarification_char
          else
            char = event.to_s
            @state.append_to_clarification_input(char) unless char.empty? || event.ctrl? || event.alt?
          end
          nil
        end

        def toggle_clarification_mode
          @state.toggle_clarification_input_mode!
          nil
        end

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
          return :scroll_up if event.up? || event.page_up?
          return :scroll_down if event.down? || event.page_down?

          nil
        end

        def handle_mouse(event)
          return :scroll_up if event.scroll_up?
          return :scroll_down if event.scroll_down?

          nil
        end
      end
    end
  end
end
