# frozen_string_literal: true

require "unicode/display_width"

module RubyCode
  module Chat
    class Renderer
      # Core chat-panel rendering: message formatting, scroll management,
      # and the main chat display area.
      module ChatPanel
        private

        def init_render_cache
          @cached_formatted_text = nil
          @cached_format_gen = -1
        end

        def cached_formatted_text(messages)
          gen = @state.message_generation
          if gen != @cached_format_gen
            @cached_formatted_text = format_messages_text(messages)
            @cached_format_gen = gen
          end
          @cached_formatted_text
        end

        def render_chat_panel(frame, area)
          init_render_cache if @cached_format_gen.nil?
          messages = @state.messages_snapshot

          if @state.streaming? && thinking_in_progress?(messages)
            render_chat_with_thinking(frame, area, messages)
          else
            render_chat_standard(frame, area, messages)
          end
        end

        def render_chat_standard(frame, area, messages)
          text = messages.empty? ? cover_banner : cached_formatted_text(messages)
          render_text_panel(frame, area, text, !messages.empty?)
        end

        def render_messages_in_area(frame, area, messages)
          text = messages.empty? ? cover_banner : format_messages_text(messages)
          render_text_panel(frame, area, text, !messages.empty?)
        end

        def render_text_panel(frame, area, text, scrollable)
          scroll_y = scrollable ? chat_scroll_y(area, text) : 0

          widget = @tui.paragraph(
            text: text,
            wrap: scrollable,
            scroll: [scroll_y, 0],
            block: @tui.block(title: chat_panel_title, borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def chat_scroll_y(area, text)
          inner_height = [area.height - 2, 0].max
          inner_width = [area.width - 2, 0].max
          total_lines = count_wrapped_lines(text, inner_width)
          @state.update_scroll_metrics(total_lines: total_lines, visible_height: inner_height)
          compute_scroll_y(total_lines, inner_height)
        end

        def chat_panel_title
          title = @state.model.to_s
          title += " [agent]" if agent_mode_active?
          title += " [plan]" if @state.respond_to?(:plan_mode_active?) && @state.plan_mode_active?
          title
        end

        def agent_mode_active?
          @state.respond_to?(:mode) && !@state.streaming? &&
            defined?(@llm_bridge) && @llm_bridge.respond_to?(:agentic_mode) &&
            @llm_bridge.agentic_mode
        end

        def chat_panel_text
          messages = @state.messages_snapshot
          messages.empty? ? cover_banner : cached_formatted_text(messages)
        end

        def format_messages_text(messages)
          messages.filter_map { |m| format_message(m) }.join("\n")
        end

        def chat_messages_text
          cached_formatted_text(@state.messages_snapshot)
        end

        def format_message(msg)
          case msg[:role]
          when :tool_call, :tool_pending, :tool_result then nil
          when :system    then "--- #{msg[:content]}"
          when :user      then "> #{msg[:content]}"
          when :assistant then format_assistant_message(msg[:content])
          else                 "#{msg[:role]}: #{msg[:content]}"
          end
        end

        def format_assistant_message(content)
          result = strip_think_tags(content)
          result.empty? ? nil : result
        end

        def compute_scroll_y(total_lines, visible_height)
          overflow = total_lines - visible_height
          return 0 if overflow <= 0

          [overflow - @state.scroll_offset, 0].max
        end

        def count_wrapped_lines(text, width)
          return 1 if width <= 0 || text.empty?

          text.split("\n", -1).sum do |line|
            line.empty? ? 1 : (display_width(line).to_f / width).ceil
          end
        end

        def display_width(line)
          Unicode::DisplayWidth.of(line)
        end
      end
    end
  end
end
