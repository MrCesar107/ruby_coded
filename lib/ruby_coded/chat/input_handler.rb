# frozen_string_literal: true

require "ratatui_ruby"

require_relative "input_handler/modal_inputs"
require_relative "input_handler/normal_mode_input"

module RubyCoded
  module Chat
    # This class is used to handle the input events for the chat
    class InputHandler
      include ModalInputs
      include NormalModeInput

      def initialize(state)
        @state = state
      end

      def process(event)
        return handle_paste(event) if event.is_a?(RatatuiRuby::Event::Paste)
        return handle_mouse(event) if event.is_a?(RatatuiRuby::Event::Mouse)
        return nil unless event.key?

        dispatch_key_event(event)
      end

      private

      def dispatch_key_event(event)
        return handle_tool_confirmation_mode(event) if @state.awaiting_tool_confirmation?
        return handle_plan_clarification_mode(event) if @state.plan_clarification?
        return handle_model_select_mode(event) if @state.model_select?
        return handle_login_mode(event) if @state.login_active?
        return handle_streaming_mode(event) if @state.streaming?

        handle_normal_mode(event)
      end
    end
  end
end
