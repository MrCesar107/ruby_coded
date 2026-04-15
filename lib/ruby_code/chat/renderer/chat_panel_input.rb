# frozen_string_literal: true

require_relative "../../initializer/cover"

module RubyCode
  module Chat
    class Renderer
      # Renders the input prompt panel and cursor at the bottom of the chat UI.
      module ChatPanelInput
        INPUT_PREFIX = "ruby_code> "

        private

        def render_input_panel(frame, area)
          prefix_len, offset, text = prepare_input_text(area)

          widget = @tui.paragraph(
            text: text,
            block: @tui.block(borders: [:all])
          )
          frame.render_widget(widget, area)
          render_input_cursor(frame, area, prefix_len, offset) unless input_locked?
        end

        def prepare_input_text(area)
          inner_width = [area.width - 2, 0].max
          prefix_len = INPUT_PREFIX.length
          text_visible_width = [inner_width - prefix_len, 0].max

          @state.update_input_visible_width(text_visible_width)
          @state.update_input_scroll_offset

          offset = @state.input_scroll_offset
          visible_slice = @state.input_buffer[offset, text_visible_width] || ""
          display_prefix = offset.positive? ? "…#{INPUT_PREFIX[1..]}" : INPUT_PREFIX

          [prefix_len, offset, "#{display_prefix}#{visible_slice}"]
        end

        def input_locked?
          @state.streaming? || @state.model_select? || @state.plan_clarification?
        end

        def render_input_cursor(frame, area, prefix_len, scroll_offset)
          cursor_x = area.x + 1 + prefix_len + (@state.cursor_position - scroll_offset)
          cursor_y = area.y + 1
          frame.set_cursor_position(cursor_x, cursor_y)
        end

        def cover_banner
          Initializer::Cover::BANNER.sub("%<version>s", RubyCode::VERSION)
        end
      end
    end
  end
end
