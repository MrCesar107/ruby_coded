# frozen_string_literal: true

module RubyCode
  module Chat
    class Renderer
      # Layout helpers for centering the plan clarifier popup.
      module PlanClarifierLayout
        private

        def clarifier_centered_popup(area)
          vertical = clarifier_centered_vertical(area)
          clarifier_centered_horizontal(vertical[1])
        end

        def clarifier_centered_vertical(area)
          @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_percentage(5),
              @tui.constraint_percentage(90),
              @tui.constraint_percentage(5)
            ]
          )
        end

        def clarifier_centered_horizontal(area)
          horizontal = @tui.layout_split(
            area,
            direction: :horizontal,
            constraints: [
              @tui.constraint_percentage(5),
              @tui.constraint_percentage(90),
              @tui.constraint_percentage(5)
            ]
          )
          horizontal[1]
        end
      end
    end
  end
end
