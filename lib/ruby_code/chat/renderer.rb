# frozen_string_literal: true

module RubyCode
  module Chat
    class Renderer
      def initialize(tui, state)
        @tui = tui
        @state = state
      end

      def draw
        @tui.clear

        @tui.draw do |frame|
          chat_area, input_area = @tui.layout_split(
            frame.area,
            direction: :vertical,
            constraints: [
              @tui.constraint_fill(1),
              @tui.constraint_length(3)
            ]
          )

          render_chat_panel(frame, chat_area)
          render_input_panel(frame, input_area)
        end
      end

      private

      def render_chat_panel(frame, area)
        lines = @state.messages_snapshot.map do |m|
          "#{m[:role]}: #{m[:content]}"
        end.join("\n")

        widget = @tui.paragraph(
          text: lines,
          block: @tui.block(
            title: @state.model.to_s,
            borders: [:all]
          )
        )
        frame.render_widget(widget, area)
      end

      def render_input_panel(frame, area)
        text = "ruby_code> #{@state.input_buffer}"
        widget = @tui.paragraph(
          text: text,
          block: @tui.block(borders: [:all])
        )
        frame.render_widget(widget, area)
      end
    end
  end
end
