# frozen_string_literal: true

module RubyCode
  module Chat
    class Renderer
      # Thinking-panel detection, parsing, and rendering for agent
      # response cycles that include tool activity or open <think> blocks.
      module ChatPanelThinking
        THINK_OPEN = "<think>"
        THINK_CLOSE = "</think>"
        TOOL_ROLES = %i[tool_call tool_pending tool_result].freeze
        MAX_THINKING_MESSAGES = 20

        private

        def thinking_in_progress?(messages)
          cycle = current_cycle_messages(messages)
          return false if cycle.empty?

          cycle.any? { |m| TOOL_ROLES.include?(m[:role]) } ||
            cycle.any? { |m| m[:role] == :assistant && open_think_block?(m[:content]) }
        end

        def current_cycle_messages(messages)
          last_user_idx = messages.rindex { |m| m[:role] == :user }
          return messages unless last_user_idx

          messages[(last_user_idx + 1)..]
        end

        def tail_of_cycle(cycle)
          return cycle if cycle.length <= MAX_THINKING_MESSAGES

          truncated = cycle.last(MAX_THINKING_MESSAGES)
          omitted = cycle.length - MAX_THINKING_MESSAGES
          header = { role: :system, content: "... #{omitted} earlier messages omitted ...", timestamp: Time.now,
                     **RubyCode::Chat::State::Messages::ZERO_TOKEN_USAGE }
          [header] + truncated
        end

        def open_think_block?(content)
          content.include?(THINK_OPEN) && !content.include?(THINK_CLOSE)
        end

        def parse_thinking_content(content)
          think_start = content.index(THINK_OPEN)
          return [nil, content, true] unless think_start

          think_end = content.index(THINK_CLOSE)
          if think_end
            parse_closed_think_block(content, think_start, think_end)
          else
            thinking = content[(think_start + THINK_OPEN.length)..]
            [thinking, content[0...think_start].strip, false]
          end
        end

        def parse_closed_think_block(content, think_start, think_end)
          thinking = content[(think_start + THINK_OPEN.length)...think_end]
          before = content[0...think_start]
          after = content[(think_end + THINK_CLOSE.length)..]
          [thinking, (before + after).strip, true]
        end

        def strip_think_tags(content)
          _, result, = parse_thinking_content(content)
          result
        end

        def format_thinking_text(cycle_messages)
          cycle_messages.map { |m| format_thinking_message(m) }.join("\n")
        end

        def format_thinking_message(msg)
          case msg[:role]
          when :assistant    then msg[:content].gsub(%r{</?think>}, "")
          when :tool_call    then ">> #{msg[:content]}"
          when :tool_pending then "?? #{msg[:content]}"
          when :tool_result  then "   #{msg[:content]}"
          when :system       then "--- #{msg[:content]}"
          else                    msg[:content]
          end
        end

        def render_chat_with_thinking(frame, area, messages)
          full_cycle = current_cycle_messages(messages)
          cycle = tail_of_cycle(full_cycle)
          prior = messages[0...(messages.length - full_cycle.length)]
          chat_area, thinking_area = split_chat_thinking(area)

          render_messages_in_area(frame, chat_area, prior)
          render_thinking_panel(frame, thinking_area, format_thinking_text(cycle))
        end

        def split_chat_thinking(area)
          @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [@tui.constraint_fill(3), @tui.constraint_fill(2)]
          )
        end

        def render_thinking_panel(frame, area, thinking_text)
          scroll_y = thinking_scroll_y(area, thinking_text)

          widget = @tui.paragraph(
            text: thinking_text,
            wrap: true,
            scroll: [scroll_y, 0],
            block: @tui.block(title: "thinking...", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def thinking_scroll_y(area, text)
          inner_height = [area.height - 2, 0].max
          inner_width = [area.width - 2, 0].max
          total_lines = count_wrapped_lines(text, inner_width)
          [total_lines - inner_height, 0].max
        end
      end
    end
  end
end
