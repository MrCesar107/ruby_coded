# frozen_string_literal: true

require_relative "login_flow_steps"

module RubyCoded
  module Chat
    class State
      # Manages the multi-step login wizard state within the TUI.
      # Steps: :provider_select -> :auth_method_select -> :api_key_input / :oauth_waiting
      module LoginFlow
        include LoginFlowSteps

        attr_reader :login_step, :login_provider, :login_auth_method,
                    :login_items, :login_select_index,
                    :login_key_buffer, :login_key_cursor,
                    :login_error, :login_oauth_result

        def init_login_flow
          reset_login_state
        end

        def login_active?
          @mode == :login
        end

        def enter_login_flow!(provider: nil)
          reset_login_state
          return enter_login_step_provider_select! unless provider

          enter_login_for_provider!(provider)
        end

        def login_select_up
          return if @login_items.empty?

          @login_select_index = (@login_select_index - 1) % @login_items.size
          mark_dirty!
        end

        def login_select_down
          return if @login_items.empty?

          @login_select_index = (@login_select_index + 1) % @login_items.size
          mark_dirty!
        end

        def login_selected_item
          @login_items[@login_select_index]
        end

        def login_advance_to_auth_method!(provider_name)
          @login_provider = provider_name
          enter_login_step_auth_method!(provider_name)
        end

        def login_advance_to_api_key!(provider_name, auth_method = :api_key)
          @login_provider = provider_name
          @login_auth_method = auth_method
          enter_login_step_api_key!(provider_name)
        end

        def login_advance_to_oauth!(provider_name)
          @login_provider = provider_name
          @login_auth_method = :oauth
          @login_step = :oauth_waiting
          @login_items = []
          @login_select_index = 0
          @login_error = nil
          @mode = :login
          mark_dirty!
        end

        def append_to_login_key(text)
          @login_key_buffer.insert(@login_key_cursor, text)
          @login_key_cursor += text.length
          @login_error = nil
          mark_dirty!
        end

        def delete_last_login_key_char
          return if @login_key_cursor <= 0

          @login_key_buffer.slice!(@login_key_cursor - 1)
          @login_key_cursor -= 1
          @login_error = nil
          mark_dirty!
        end

        def login_set_oauth_result!(result)
          @mutex.synchronize do
            @login_oauth_result = result
            @dirty = true
          end
        end

        def login_clear_oauth_result!
          @login_oauth_result = nil
        end

        def login_set_error!(msg)
          @login_error = msg
          mark_dirty!
        end

        def exit_login_flow!
          @mode = :chat
          reset_login_state
          mark_dirty!
        end

        def login_provider_module
          providers_map[@login_provider]
        end
      end
    end
  end
end
