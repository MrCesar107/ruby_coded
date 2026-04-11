# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # This module contains the logic for the commands' history management
      module HistoryCommands
        private

        def cmd_history(_rest)
          conv = conversation_messages
          if conv.empty?
            @state.add_message(:system, "No conversation history yet.")
            return
          end

          @state.add_message(:system, format_history(conv))
        end

        def conversation_messages
          @state.messages_snapshot.reject { |m| m[:role] == :system }
        end

        def format_history(conv)
          lines = conv.map.with_index(1) { |msg, i| format_history_line(msg, i) }
          "Conversation history (#{conv.size} messages):\n#{lines.join("\n")}"
        end

        def format_history_line(msg, index)
          role = msg[:role].to_s.capitalize
          preview = msg[:content].to_s.lines.first&.strip || ""
          preview = "#{preview[0..60]}..." if preview.length > 60
          "  #{index}. [#{role}] #{preview}"
        end

        def cmd_tokens(_rest)
          breakdown = @state.session_cost_breakdown

          if breakdown.empty?
            @state.add_message(:system, "No token usage recorded yet.")
            return
          end

          lines = []
          lines << "Session Token Usage & Cost Report"
          lines << "═" * 50

          breakdown.each do |entry|
            lines << format_token_entry(entry)
          end

          lines << "─" * 50
          lines << format_token_totals(breakdown)

          @state.add_message(:system, lines.join("\n"))
        end

        def format_token_entry(entry)
          lines = []
          lines << "Model: #{entry[:model]}"

          if entry[:input_price_per_million]
            format_priced_entry(lines, entry)
          else
            format_unpriced_entry(lines, entry)
          end

          lines.join("\n")
        end

        def format_priced_entry(lines, entry)
          lines << "  Input:    #{format_num(entry[:input_tokens])} tokens  " \
                    "(#{format_usd(entry[:input_cost])} @ $#{entry[:input_price_per_million]}/1M)"
          lines << "  Output:   #{format_num(entry[:output_tokens])} tokens  " \
                    "(#{format_usd(entry[:output_cost])} @ $#{entry[:output_price_per_million]}/1M)"

          if entry[:thinking_tokens] > 0
            lines << "  Thinking: #{format_num(entry[:thinking_tokens])} tokens  " \
                      "(#{format_usd(entry[:thinking_cost])} @ $#{entry[:thinking_price_per_million]}/1M)"
          end

          if entry[:cached_tokens] > 0
            lines << "  Cached:   #{format_num(entry[:cached_tokens])} tokens  " \
                      "(#{format_usd(entry[:cached_cost])} @ $#{entry[:cached_input_price_per_million]}/1M)"
          end

          if entry[:cache_creation_tokens] > 0
            lines << "  Cache wr: #{format_num(entry[:cache_creation_tokens])} tokens  " \
                      "(#{format_usd(entry[:cache_creation_cost])} @ $#{entry[:cache_creation_price_per_million]}/1M)"
          end

          lines << "  Subtotal: #{format_num(entry_total_tokens(entry))} tokens  #{format_usd(entry[:total_cost])}"
        end

        def format_unpriced_entry(lines, entry)
          lines << "  Input:    #{format_num(entry[:input_tokens])} tokens"
          lines << "  Output:   #{format_num(entry[:output_tokens])} tokens"
          lines << "  Thinking: #{format_num(entry[:thinking_tokens])} tokens" if entry[:thinking_tokens] > 0
          lines << "  Cached:   #{format_num(entry[:cached_tokens])} tokens" if entry[:cached_tokens] > 0
          lines << "  Subtotal: #{format_num(entry_total_tokens(entry))} tokens  (pricing unavailable)"
        end

        def entry_total_tokens(entry)
          entry[:input_tokens] + entry[:output_tokens] + entry[:thinking_tokens] +
            entry[:cached_tokens] + entry[:cache_creation_tokens]
        end

        def format_token_totals(breakdown)
          total_input = breakdown.sum { |e| e[:input_tokens] }
          total_output = breakdown.sum { |e| e[:output_tokens] }
          total_thinking = breakdown.sum { |e| e[:thinking_tokens] }
          total_tokens = total_input + total_output + total_thinking
          costs = breakdown.map { |e| e[:total_cost] }.compact
          total_cost = costs.empty? ? nil : costs.sum

          cost_str = total_cost ? format_usd(total_cost) : "N/A"
          parts = ["↑#{format_num(total_input)}", "↓#{format_num(total_output)}"]
          parts << "💭#{format_num(total_thinking)}" if total_thinking > 0
          "Total: #{format_num(total_tokens)} tokens (#{parts.join(" ")}) | Cost: #{cost_str}"
        end

        def format_num(num)
          num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
        end

        def format_usd(amount)
          return "N/A" if amount.nil?

          "$#{format("%.2f", amount)}"
        end
      end
    end
  end
end
