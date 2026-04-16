# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Layout helpers for centering the login flow popup.
      module LoginFlowLayout
        private

        def login_centered_popup(area)
          vertical = login_centered_vertical(area)
          login_centered_horizontal(vertical[1])
        end

        def login_centered_vertical(area)
          @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_percentage(15),
              @tui.constraint_percentage(70),
              @tui.constraint_percentage(15)
            ]
          )
        end

        def login_centered_horizontal(area)
          horizontal = @tui.layout_split(
            area,
            direction: :horizontal,
            constraints: [
              @tui.constraint_percentage(20),
              @tui.constraint_percentage(60),
              @tui.constraint_percentage(20)
            ]
          )
          horizontal[1]
        end

        def login_select_layout(popup_area)
          @tui.layout_split(
            popup_area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
        end

        def login_api_key_layout(popup_area)
          @tui.layout_split(
            popup_area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(5),
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
        end
      end
    end
  end
end
