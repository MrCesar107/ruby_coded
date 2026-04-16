# frozen_string_literal: true

module RubyCoded
  module Chat
    class InputHandler
      # Handles input events for the multi-step login wizard:
      # provider selection, auth method selection, API key entry, and OAuth waiting.
      module LoginInputs
        private

        def handle_login_mode(event)
          return :quit if event.ctrl_c?

          case @state.login_step
          when :provider_select, :auth_method_select
            handle_login_select(event)
          when :api_key_input
            handle_login_key_input(event)
          when :oauth_waiting
            handle_login_oauth_waiting(event)
          end
        end

        def handle_login_select(event)
          return :login_cancel if event.esc?
          return login_select_confirmed if event.enter?

          if event.up?
            @state.login_select_up
          elsif event.down?
            @state.login_select_down
          end
          nil
        end

        def login_select_confirmed
          @state.login_step == :provider_select ? :login_provider_selected : :login_method_selected
        end

        def handle_login_key_input(event)
          return :login_cancel if event.esc?
          return handle_login_key_enter if event.enter?
          return @state.delete_last_login_key_char if event.backspace?

          append_login_key_char(event)
        end

        def handle_login_key_enter
          @state.login_key_buffer.strip.empty? ? nil : :login_key_submitted
        end

        def append_login_key_char(event)
          char = event.to_s
          @state.append_to_login_key(char) unless char.empty? || event.ctrl? || event.alt?
          nil
        end

        def handle_login_oauth_waiting(event)
          return :login_oauth_cancel if event.esc?

          nil
        end
      end
    end
  end
end
