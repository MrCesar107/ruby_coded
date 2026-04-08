# frozen_string_literal: true

module RubyCode
  module Chat
    class Renderer
      # This module contains the logic for rendering the UI model selector component
      module ModelSelector
        private

        def render_model_selector(frame, area)
          popup_area = centered_popup(area)
          frame.render_widget(@tui.clear, popup_area)

          search_area, list_area = popup_layout(popup_area)
          render_model_search(frame, search_area)
          render_model_list(frame, list_area)
        end

        def popup_layout(popup_area)
          @tui.layout_split(
            popup_area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
        end

        def render_model_search(frame, area)
          widget = @tui.paragraph(
            text: "Search: #{@state.model_select_filter}",
            block: @tui.block(title: "↑↓ navigate, Enter select, Esc cancel", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_model_list(frame, area)
          filtered = @state.filtered_model_list
          items = filtered.map { |m| model_display_label(m) }
          widget = model_list_widget(items, filtered.size)
          frame.render_widget(widget, area)
        end

        def model_list_widget(items, count)
          title = @state.model_select_show_all? ? "All Models (#{count})" : "Models (#{count})"
          @tui.list(
            items: items,
            selected_index: @state.model_select_index,
            highlight_style: @tui.style(bg: :blue, fg: :white, modifiers: [:bold]),
            highlight_symbol: "> ",
            scroll_padding: 2,
            block: @tui.block(title: title, borders: [:all])
          )
        end

        def centered_popup(area)
          vertical = centered_vertical(area)
          centered_horizontal(vertical[1])
        end

        def centered_vertical(area)
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

        def centered_horizontal(area)
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

        def model_display_label(model)
          id = model.respond_to?(:id) ? model.id : model.to_s
          provider = model.respond_to?(:provider) ? model.provider : "unknown"
          current_marker = id == @state.model ? " *" : ""
          "#{id} (#{provider})#{current_marker}"
        end
      end
    end
  end
end
