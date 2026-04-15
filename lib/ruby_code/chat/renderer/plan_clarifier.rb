# frozen_string_literal: true

module RubyCode
  module Chat
    class Renderer
      # Renders a centered popup for plan clarification questions.
      # The popup has three zones: question, options list, and free text input.
      module PlanClarifier
        private

        def render_plan_clarifier(frame, area)
          popup_area = clarifier_centered_popup(area)
          frame.render_widget(@tui.clear, popup_area)

          question_area, options_area, input_area = clarifier_layout(popup_area)
          render_clarifier_question(frame, question_area)
          render_clarifier_options(frame, options_area)
          render_clarifier_input(frame, input_area)
        end

        def clarifier_layout(popup_area)
          question_height = clarifier_question_height(popup_area.width)

          @tui.layout_split(
            popup_area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(question_height),
              @tui.constraint_fill(1),
              @tui.constraint_length(3)
            ]
          )
        end

        def clarifier_question_height(popup_width)
          question = @state.clarification_question || ""
          inner_width = [popup_width - 2, 1].max
          wrapped = (question.length.to_f / inner_width).ceil
          [wrapped + 2, 4].max
        end

        def render_clarifier_question(frame, area)
          question = @state.clarification_question || ""
          widget = @tui.paragraph(
            text: question,
            wrap: true,
            block: @tui.block(title: "Plan Clarification", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_clarifier_options(frame, area)
          options = @state.clarification_options

          widget = @tui.list(
            items: wrap_clarifier_items(options, [area.width - 4, 1].max),
            selected_index: @state.clarification_index,
            highlight_style: clarifier_highlight_style,
            highlight_symbol: "> ",
            scroll_padding: 1,
            block: @tui.block(title: "Options (#{options.size})", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def wrap_clarifier_items(options, width)
          options.each_with_index.map do |opt, i|
            clarifier_wrap_option("[#{i + 1}] #{opt}", width)
          end
        end

        def clarifier_highlight_style
          if @state.clarification_input_mode == :options
            @tui.style(bg: :blue, fg: :white, modifiers: [:bold])
          else
            @tui.style(fg: :dark_gray)
          end
        end

        def render_clarifier_input(frame, area)
          active = @state.clarification_input_mode == :custom
          hint = active ? "Enter: send | Tab: back to options" : "Tab: switch to free text | Esc: skip"
          text = active ? ">> #{@state.clarification_custom_input}" : hint

          widget = @tui.paragraph(
            text: text,
            wrap: true,
            block: @tui.block(title: "Free response", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        # Wraps a single option string into multiple lines that fit the
        # available width, preserving word boundaries when possible.
        def clarifier_wrap_option(text, max_width)
          return text if text.length <= max_width

          lines = []
          remaining = text
          while remaining.length > max_width
            break_at = remaining.rindex(" ", max_width) || max_width
            lines << remaining[0...break_at]
            remaining = remaining[break_at..].lstrip
          end
          lines << remaining unless remaining.empty?
          lines.join("\n")
        end

      end
    end
  end
end
