# frozen_string_literal: true

module RubyCoded
  module Chat
    class CommandHandler
      # Slash command for authenticating with AI providers from within the TUI.
      module LoginCommands
        private

        def cmd_login(rest)
          provider_name = rest&.strip&.downcase

          if provider_name && !provider_name.empty?
            return show_login_usage unless valid_providers.include?(provider_name)

            @state.enter_login_flow!(provider: provider_name.to_sym)
          else
            @state.enter_login_flow!
          end
        end

        def valid_providers
          RubyCoded::Auth::AuthManager::PROVIDERS.keys.map(&:to_s)
        end

        def show_login_usage
          providers = valid_providers.join(", ")
          @state.add_message(:system, "Usage: /login [#{providers}]")
        end
      end
    end
  end
end
