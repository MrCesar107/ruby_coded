# frozen_string_literal: true

module RubyCode
  module Plugins
    module CommandCompletion
      # Mixed into Chat::Renderer to draw a compact suggestion popup
      # directly above the input panel when completions are active.
      module RendererExtension
        private

        def render_command_completer(frame, chat_area, _input_area)
          return unless @state.command_completion_active?

          suggestions = @state.command_suggestions
          return if suggestions.empty?

          popup_area = completer_popup_area(chat_area, suggestions.size)
          frame.render_widget(@tui.clear, popup_area)

          items = suggestions.map { |cmd, desc| format_suggestion(cmd, desc) }
          widget = completer_list_widget(items)
          frame.render_widget(widget, popup_area)
        end

        def completer_popup_area(chat_area, count)
          height = [count + 2, 10].min
          popup_y = [chat_area.y + chat_area.height - height, chat_area.y].max
          popup_width = [chat_area.width / 2, 40].max

          @tui.rect(
            x: chat_area.x,
            y: popup_y,
            width: [popup_width, chat_area.width].min,
            height: height
          )
        end

        def completer_list_widget(items)
          @tui.list(
            items: items,
            selected_index: @state.command_completion_index,
            highlight_style: @tui.style(bg: :blue, fg: :white, modifiers: [:bold]),
            highlight_symbol: "> ",
            block: @tui.block(borders: [:all])
          )
        end

        def format_suggestion(cmd, desc)
          "#{cmd.ljust(16)} #{desc}"
        end
      end
    end
  end
end
