# frozen_string_literal: true

module RubyCode
  module Plugins
    module CommandCompletion
      # Mixed into Chat::InputHandler to intercept Tab and arrow keys
      # when command completion suggestions are visible.
      module InputExtension
        private

        def handle_command_completion_input(event)
          return nil unless @state.command_completion_active?

          if event.tab?
            @state.accept_command_completion!
            return :plugin_handled
          end

          if event.up?
            @state.command_completion_up
            return :plugin_handled
          end

          if event.down?
            @state.command_completion_down
            return :plugin_handled
          end

          nil
        end
      end
    end
  end
end
