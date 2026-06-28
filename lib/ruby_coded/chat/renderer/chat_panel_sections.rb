# frozen_string_literal: true

require "unicode/display_width"

module RubyCoded
  module Chat
    class Renderer
      # Section building, sticky-header computation, and line-measurement
      # helpers backing the chat panel's scroll-aware rendering.
      module ChatPanelSections
        private

        def build_chat_sections(messages)
          sections = []
          visible_index = 0

          messages.each do |msg|
            text = format_message(msg)
            next if text.nil?

            section = next_section_for(sections, msg, text)
            section[:entries] << { role: msg[:role], text: text, visible_index: visible_index }
            visible_index += 1
          end

          sections
        end

        def next_section_for(sections, msg, text)
          return sections.last if sections.any? && msg[:role] != :user

          sections << { user_text: msg[:role] == :user ? text : nil, entries: [] }
          sections.last
        end

        def sections_to_text(sections)
          sections.flat_map { |section| section[:entries].map { |entry| entry[:text] } }.join("\n")
        end

        def sticky_header_for(area, sections)
          return nil if sections.empty?
          return nil if @state.scroll_offset <= 0

          inner_width = [area.width - 2, 0].max
          inner_height = [area.height - 2, 0].max
          return nil if inner_width <= 0 || inner_height <= 0

          layout = build_section_layout(sections, inner_width)
          active = active_sticky_section(layout, inner_height)
          return nil unless active

          { header_text: active[:user_text] }
        end

        def build_section_layout(sections, inner_width)
          cursor = 0

          sections.map do |section|
            entry_layouts = section[:entries].map do |entry|
              layout = layout_entry(entry, inner_width, cursor)
              cursor = layout[:end_line] + 1
              layout
            end
            section_layout(section, entry_layouts)
          end
        end

        def layout_entry(entry, inner_width, start_line)
          wrapped_lines = count_wrapped_lines(entry[:text], inner_width)
          entry.merge(
            wrapped_lines: wrapped_lines,
            start_line: start_line,
            end_line: start_line + wrapped_lines - 1
          )
        end

        def section_layout(section, entry_layouts)
          user_entry = entry_layouts.find { |entry| entry[:role] == :user }
          {
            user_text: section[:user_text],
            entries: entry_layouts,
            start_line: entry_layouts.first[:start_line],
            end_line: entry_layouts.last[:end_line],
            user_end_line: user_entry ? user_entry[:end_line] : nil
          }
        end

        def active_sticky_section(layout, visible_height)
          return nil if layout.empty?

          total_lines = layout.last[:end_line] + 1
          top_visible_line = compute_scroll_y(total_lines, visible_height)

          layout.find do |section|
            next false unless section[:user_text]
            next false unless line_in_section?(top_visible_line, section)
            next false if section[:user_end_line] && top_visible_line <= section[:user_end_line]

            true
          end
        end

        def line_in_section?(line_index, section)
          line_index.between?(section[:start_line], section[:end_line])
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
