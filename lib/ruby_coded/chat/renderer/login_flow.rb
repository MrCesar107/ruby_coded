# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Renders a centered popup for the multi-step login wizard.
      module LoginFlow
        private

        def render_login_flow(frame, area)
          popup_area = login_centered_popup(area)
          frame.render_widget(@tui.clear, popup_area)

          case @state.login_step
          when :provider_select    then render_login_select(frame, popup_area, title: "Select AI Provider")
          when :auth_method_select then render_login_select(frame, popup_area, title: "Select Auth Method")
          when :api_key_input      then render_login_api_key(frame, popup_area)
          when :oauth_waiting      then render_login_oauth_waiting(frame, popup_area)
          end
        end

        def render_login_select(frame, popup_area, title:)
          hint_area, list_area = login_select_layout(popup_area)
          render_login_hint(frame, hint_area)
          render_login_list(frame, list_area, title)
        end

        def render_login_hint(frame, area)
          widget = @tui.paragraph(
            text: "↑↓ navigate, Enter select, Esc cancel",
            block: @tui.block(title: "Login", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_login_list(frame, area, title)
          items = @state.login_items.map { |item| item[:label] }
          widget = @tui.list(
            items: items,
            selected_index: @state.login_select_index,
            highlight_style: @tui.style(bg: :blue, fg: :white, modifiers: [:bold]),
            highlight_symbol: "> ",
            scroll_padding: 2,
            block: @tui.block(title: title, borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_login_api_key(frame, popup_area)
          provider = @state.login_provider_module
          info_area, input_area, error_area = login_api_key_layout(popup_area)

          render_login_api_key_info(frame, info_area, provider)
          render_login_api_key_input(frame, input_area)
          render_login_api_key_error(frame, error_area)
        end

        def render_login_api_key_info(frame, area, provider)
          console = provider.respond_to?(:console_url) ? provider.console_url : ""
          text = "Generate your API key at:\n#{console}"
          widget = @tui.paragraph(
            text: text,
            wrap: true,
            block: @tui.block(title: "#{provider.display_name} API Key", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_login_api_key_input(frame, area)
          masked = "*" * @state.login_key_buffer.length
          widget = @tui.paragraph(
            text: "Key: #{masked}",
            block: @tui.block(title: "Enter submit, Esc cancel", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_login_api_key_error(frame, area)
          error = @state.login_error
          text = error || ""
          style = error ? @tui.style(fg: :red) : @tui.style(fg: :dark_gray)
          widget = @tui.paragraph(
            text: text,
            style: style,
            wrap: true,
            block: @tui.block(borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_login_oauth_waiting(frame, popup_area)
          provider = @state.login_provider_module
          widget = @tui.paragraph(
            text: "Your browser has been opened for authentication.\n\n" \
                  "Waiting for #{provider.display_name} callback...\n\n" \
                  "Press Esc to cancel.",
            wrap: true,
            block: @tui.block(title: "Authenticating with #{provider.display_name}", borders: [:all])
          )
          frame.render_widget(widget, popup_area)
        end
      end
    end
  end
end
