# frozen_string_literal: true

require_relative "../initializer/cover"

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
          render_model_selector(frame, chat_area) if @state.model_select?
        end
      end

      private

      def render_chat_panel(frame, area)
        messages = @state.messages_snapshot
        text = if messages.empty?
                 cover_banner
               else
                 messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")
               end

        widget = @tui.paragraph(
          text: text,
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

      def render_model_selector(frame, area)
        popup_area = centered_popup(area)
        frame.render_widget(@tui.clear, popup_area)

        search_area, list_area = @tui.layout_split(
          popup_area,
          direction: :vertical,
          constraints: [
            @tui.constraint_length(3),
            @tui.constraint_fill(1)
          ]
        )

        filter_text = "Search: #{@state.model_select_filter}"
        search_widget = @tui.paragraph(
          text: filter_text,
          block: @tui.block(
            title: "↑↓ navigate, Enter select, Esc cancel",
            borders: [:all]
          )
        )
        frame.render_widget(search_widget, search_area)

        filtered = @state.filtered_model_list
        items = filtered.map { |m| model_display_label(m) }

        list_widget = @tui.list(
          items: items,
          selected_index: @state.model_select_index,
          highlight_style: @tui.style(bg: :blue, fg: :white, modifiers: [:bold]),
          highlight_symbol: "> ",
          scroll_padding: 2,
          block: @tui.block(
            title: "Models (#{filtered.size})",
            borders: [:all]
          )
        )
        frame.render_widget(list_widget, list_area)
      end

      def centered_popup(area)
        vertical = @tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            @tui.constraint_percentage(15),
            @tui.constraint_percentage(70),
            @tui.constraint_percentage(15)
          ]
        )

        horizontal = @tui.layout_split(
          vertical[1],
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

      def cover_banner
        Initializer::Cover::BANNER.sub("%<version>s", RubyCode::VERSION)
      end
    end
  end
end
