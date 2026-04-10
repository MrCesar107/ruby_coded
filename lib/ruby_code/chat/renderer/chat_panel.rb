# frozen_string_literal: true

require_relative "../../initializer/cover"

module RubyCode
  module Chat
    class Renderer
      # This module contains the logic for rendering the UI chat panel component
      module ChatPanel
        THINK_OPEN = "<think>"
        THINK_CLOSE = "</think>"
        TOOL_ROLES = %i[tool_call tool_pending tool_result].freeze
        MAX_THINKING_MESSAGES = 20

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
          has_messages = !messages.empty?
          text = has_messages ? cached_formatted_text(messages) : cover_banner
          inner_height = [area.height - 2, 0].max
          inner_width = [area.width - 2, 0].max

          if has_messages
            total_lines = count_wrapped_lines(text, inner_width)
            @state.update_scroll_metrics(total_lines: total_lines, visible_height: inner_height)
            scroll_y = compute_scroll_y(total_lines, inner_height)
          else
            scroll_y = 0
          end

          widget = @tui.paragraph(
            text: text,
            wrap: has_messages,
            scroll: [scroll_y, 0],
            block: @tui.block(title: chat_panel_title, borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        # Splits the chat area: prior messages on top, current agent
        # cycle (thinking + tool activity) in a bottom panel.
        def render_chat_with_thinking(frame, area, messages)
          full_cycle = current_cycle_messages(messages)
          cycle = tail_of_cycle(full_cycle)
          prior = messages[0...(messages.length - full_cycle.length)]

          chat_area, thinking_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_fill(3),
              @tui.constraint_fill(2)
            ]
          )

          render_messages_in_area(frame, chat_area, prior)
          render_thinking_panel(frame, thinking_area, format_thinking_text(cycle))
        end

        def render_messages_in_area(frame, area, messages)
          has_messages = !messages.empty?
          text = has_messages ? format_messages_text(messages) : cover_banner
          inner_height = [area.height - 2, 0].max
          inner_width = [area.width - 2, 0].max

          if has_messages
            total_lines = count_wrapped_lines(text, inner_width)
            @state.update_scroll_metrics(total_lines: total_lines, visible_height: inner_height)
            scroll_y = compute_scroll_y(total_lines, inner_height)
          else
            scroll_y = 0
          end

          widget = @tui.paragraph(
            text: text,
            wrap: has_messages,
            scroll: [scroll_y, 0],
            block: @tui.block(title: chat_panel_title, borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def render_thinking_panel(frame, area, thinking_text)
          inner_height = [area.height - 2, 0].max
          inner_width = [area.width - 2, 0].max
          total_lines = count_wrapped_lines(thinking_text, inner_width)
          overflow = total_lines - inner_height
          scroll_y = [overflow, 0].max

          widget = @tui.paragraph(
            text: thinking_text,
            wrap: true,
            scroll: [scroll_y, 0],
            block: @tui.block(title: "thinking...", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        # --- Thinking detection ---

        # The thinking panel is active when the current agent cycle
        # contains tool activity OR an open <think> block.
        def thinking_in_progress?(messages)
          cycle = current_cycle_messages(messages)
          return false if cycle.empty?

          cycle.any? { |m| TOOL_ROLES.include?(m[:role]) } ||
            cycle.any? { |m| m[:role] == :assistant && open_think_block?(m[:content]) }
        end

        # Everything after the last :user message belongs to the
        # current agent response cycle.
        def current_cycle_messages(messages)
          last_user_idx = messages.rindex { |m| m[:role] == :user }
          return messages unless last_user_idx

          messages[(last_user_idx + 1)..]
        end

        # Keep only the tail of the cycle for display, avoiding a
        # panel that grows unbounded with completed operations.
        def tail_of_cycle(cycle)
          return cycle if cycle.length <= MAX_THINKING_MESSAGES

          truncated = cycle.last(MAX_THINKING_MESSAGES)
          omitted = cycle.length - MAX_THINKING_MESSAGES
          header = { role: :system, content: "... #{omitted} earlier messages omitted ...", timestamp: Time.now,
                     input_tokens: 0, output_tokens: 0 }
          [header] + truncated
        end

        def open_think_block?(content)
          content.include?(THINK_OPEN) && !content.include?(THINK_CLOSE)
        end

        # --- Think tag parsing ---

        # Splits content around <think>...</think> tags.
        # Returns [thinking_text, result_text, thinking_complete?].
        def parse_thinking_content(content)
          think_start = content.index(THINK_OPEN)
          return [nil, content, true] unless think_start

          think_end = content.index(THINK_CLOSE)
          if think_end
            thinking = content[(think_start + THINK_OPEN.length)...think_end]
            before = content[0...think_start]
            after = content[(think_end + THINK_CLOSE.length)..]
            [thinking, (before + after).strip, true]
          else
            thinking = content[(think_start + THINK_OPEN.length)..]
            [thinking, content[0...think_start].strip, false]
          end
        end

        def strip_think_tags(content)
          _, result, = parse_thinking_content(content)
          result
        end

        # --- Thinking panel formatting ---

        def format_thinking_text(cycle_messages)
          cycle_messages.map { |m| format_thinking_message(m) }.join("\n")
        end

        def format_thinking_message(msg)
          case msg[:role]
          when :assistant
            msg[:content].gsub(%r{</?think>}, "")
          when :tool_call
            ">> #{msg[:content]}"
          when :tool_pending
            "?? #{msg[:content]}"
          when :tool_result
            "   #{msg[:content]}"
          when :system
            "--- #{msg[:content]}"
          else
            msg[:content]
          end
        end

        # --- Main chat formatting ---

        def chat_panel_title
          title = @state.model.to_s
          title += " [agent]" if @state.respond_to?(:mode) && @state.streaming? == false &&
                                 defined?(@llm_bridge) && @llm_bridge.respond_to?(:agentic_mode) &&
                                 @llm_bridge.agentic_mode
          title += " [plan]" if @state.respond_to?(:plan_mode_active?) && @state.plan_mode_active?
          title
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

        # Tool messages are only visible inside the thinking panel;
        # the main chat shows user prompts, system notices and the
        # final assistant result (with think tags stripped).
        def format_message(msg)
          case msg[:role]
          when :tool_call, :tool_pending, :tool_result
            nil
          when :system
            "--- #{msg[:content]}"
          when :user
            "> #{msg[:content]}"
          when :assistant
            result = strip_think_tags(msg[:content])
            result.empty? ? nil : result
          else
            "#{msg[:role]}: #{msg[:content]}"
          end
        end

        def compute_scroll_y(total_lines, visible_height)
          overflow = total_lines - visible_height
          return 0 if overflow <= 0

          [overflow - @state.scroll_offset, 0].max
        end

        def count_wrapped_lines(text, width)
          return 1 if width <= 0 || text.empty?

          text.split("\n", -1).sum do |line|
            line.empty? ? 1 : (line.length.to_f / width).ceil
          end
        end

        INPUT_PREFIX = "ruby_code> "

        def render_input_panel(frame, area)
          text = "#{INPUT_PREFIX}#{@state.input_buffer}"
          widget = @tui.paragraph(
            text: text,
            block: @tui.block(borders: [:all])
          )
          frame.render_widget(widget, area)
          render_input_cursor(frame, area) unless @state.streaming? || @state.model_select? || @state.plan_clarification?
        end

        def render_input_cursor(frame, area)
          cursor_x = area.x + 1 + INPUT_PREFIX.length + @state.cursor_position
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
