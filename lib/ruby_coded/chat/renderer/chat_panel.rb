# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Core chat-panel rendering pipeline: widget composition, caching,
      # and scroll-aware layout for the main chat display area.
      module ChatPanel
        STICKY_HEADER_TITLE = "current prompt"
        STICKY_HEADER_HEIGHT = 4

        private

        def init_render_cache
          @cached_chat_sections = nil
          @cached_format_gen = -1
        end

        def cached_chat_sections(messages)
          gen = @state.message_generation
          if gen != @cached_format_gen
            @cached_chat_sections = build_chat_sections(messages)
            @cached_format_gen = gen
          end
          @cached_chat_sections
        end

        def cached_formatted_text(messages)
          sections_to_text(cached_chat_sections(messages))
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
          return render_text_panel(frame, area, cover_banner, false) if messages.empty?

          sections = cached_chat_sections(messages)
          sticky = sticky_header_for(area, sections)

          if sticky
            header_area, body_area = split_chat_sticky(area)
            render_sticky_header(frame, header_area, sticky[:header_text])
            render_sections_panel(frame, body_area, sections)
          else
            render_sections_panel(frame, area, sections)
          end
        end

        def render_messages_in_area(frame, area, messages)
          return render_text_panel(frame, area, cover_banner, false) if messages.empty?

          render_sections_panel(frame, area, build_chat_sections(messages))
        end

        def render_sections_panel(frame, area, sections)
          text = sections_to_text(sections)
          render_text_panel(frame, area, text, true)
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

        def render_sticky_header(frame, area, text)
          widget = @tui.paragraph(
            text: text,
            wrap: true,
            scroll: [0, 0],
            block: @tui.block(title: STICKY_HEADER_TITLE, borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def split_chat_sticky(area)
          @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [@tui.constraint_length(STICKY_HEADER_HEIGHT), @tui.constraint_fill(1)]
          )
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
          @state.respond_to?(:agentic_mode?) && @state.agentic_mode?
        end

        def chat_panel_text
          messages = @state.messages_snapshot
          messages.empty? ? cover_banner : cached_formatted_text(messages)
        end

        def compute_scroll_y(total_lines, visible_height)
          overflow = total_lines - visible_height
          return 0 if overflow <= 0

          [overflow - @state.scroll_offset, 0].max
        end
      end
    end
  end
end
