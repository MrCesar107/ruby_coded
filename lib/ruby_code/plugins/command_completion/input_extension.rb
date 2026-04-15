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
          return :plugin_handled if dispatch_completion(event)

          nil
        end

        def dispatch_completion(event)
          if event.tab?
            @state.accept_command_completion!
          elsif event.up?
            @state.command_completion_up
          elsif event.down?
            @state.command_completion_down
          end
        end
      end
    end
  end
end
