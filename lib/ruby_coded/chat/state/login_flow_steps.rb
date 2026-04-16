# frozen_string_literal: true

module RubyCoded
  module Chat
    class State
      # Private helpers for LoginFlow: state reset, provider lookup,
      # and step-specific initialization.
      module LoginFlowSteps
        private

        def reset_login_state
          @login_step = nil
          @login_provider = nil
          @login_auth_method = nil
          @login_items = []
          @login_select_index = 0
          @login_key_buffer = String.new
          @login_key_cursor = 0
          @login_error = nil
          @login_oauth_result = nil
        end

        def providers_map
          RubyCoded::Auth::AuthManager::PROVIDERS
        end

        def enter_login_for_provider!(provider)
          methods = providers_map[provider].auth_methods
          if methods.size == 1
            enter_login_step_api_key!(provider)
          else
            enter_login_step_auth_method!(provider)
          end
        end

        def enter_login_step_provider_select!
          @login_step = :provider_select
          @login_items = providers_map.map { |key, prov| { key: key, label: prov.display_name } }
          @login_select_index = 0
          @mode = :login
          mark_dirty!
        end

        def enter_login_step_auth_method!(provider_name)
          @login_provider = provider_name
          provider = providers_map[provider_name]
          @login_step = :auth_method_select
          @login_items = provider.auth_methods
          @login_select_index = 0
          @mode = :login
          mark_dirty!
        end

        def enter_login_step_api_key!(provider_name)
          @login_provider = provider_name
          @login_auth_method = :api_key
          @login_step = :api_key_input
          @login_items = []
          @login_select_index = 0
          @login_key_buffer = String.new
          @login_key_cursor = 0
          @login_error = nil
          @mode = :login
          mark_dirty!
        end
      end
    end
  end
end
