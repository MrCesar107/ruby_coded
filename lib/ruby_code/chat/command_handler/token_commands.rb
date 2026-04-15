# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # Slash commands for displaying session token usage and cost reports.
      module TokenCommands
        private

        def cmd_tokens(_rest)
          breakdown = @state.session_cost_breakdown

          if breakdown.empty?
            @state.add_message(:system, "No token usage recorded yet.")
            return
          end

          @state.add_message(:system, build_token_report(breakdown))
        end

        def build_token_report(breakdown)
          lines = ["Session Token Usage & Cost Report", "═" * 50]
          breakdown.each { |entry| lines << format_token_entry(entry) }
          lines << ("─" * 50)
          lines << format_token_totals(breakdown)
          lines.join("\n")
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
          append_base_priced_lines(lines, entry)
          append_optional_priced_lines(lines, entry)
          lines << subtotal_line(entry)
        end

        def append_base_priced_lines(lines, entry)
          lines << priced_line("Input:   ", entry[:input_tokens], entry[:input_cost], entry[:input_price_per_million])
          lines << priced_line("Output:  ", entry[:output_tokens], entry[:output_cost],
                               entry[:output_price_per_million])
        end

        def append_optional_priced_lines(lines, entry)
          optional_priced_fields.each do |label, tokens_key, cost_key, price_key|
            next unless entry[tokens_key].positive?

            lines << priced_line(label, entry[tokens_key], entry[cost_key], entry[price_key])
          end
        end

        def optional_priced_fields
          [
            ["Thinking:", :thinking_tokens, :thinking_cost, :thinking_price_per_million],
            ["Cached:  ", :cached_tokens, :cached_cost, :cached_input_price_per_million],
            ["Cache wr:", :cache_creation_tokens, :cache_creation_cost, :cache_creation_price_per_million]
          ]
        end

        def priced_line(label, tokens, cost, price_per_million)
          "  #{label} #{format_num(tokens)} tokens  (#{format_usd(cost)} @ $#{price_per_million}/1M)"
        end

        def subtotal_line(entry)
          "  Subtotal: #{format_num(entry_total_tokens(entry))} tokens  #{format_usd(entry[:total_cost])}"
        end

        def format_unpriced_entry(lines, entry)
          lines << "  Input:    #{format_num(entry[:input_tokens])} tokens"
          lines << "  Output:   #{format_num(entry[:output_tokens])} tokens"
          append_optional_unpriced_lines(lines, entry)
          lines << "  Subtotal: #{format_num(entry_total_tokens(entry))} tokens  (pricing unavailable)"
        end

        def append_optional_unpriced_lines(lines, entry)
          lines << "  Thinking: #{format_num(entry[:thinking_tokens])} tokens" if entry[:thinking_tokens].positive?
          lines << "  Cached:   #{format_num(entry[:cached_tokens])} tokens" if entry[:cached_tokens].positive?
        end

        def entry_total_tokens(entry)
          entry[:input_tokens] + entry[:output_tokens] + entry[:thinking_tokens] +
            entry[:cached_tokens] + entry[:cache_creation_tokens]
        end

        def format_token_totals(breakdown)
          totals = compute_totals(breakdown)
          format_totals_summary(totals)
        end

        def compute_totals(breakdown)
          {
            input: breakdown.sum { |e| e[:input_tokens] },
            output: breakdown.sum { |e| e[:output_tokens] },
            thinking: breakdown.sum { |e| e[:thinking_tokens] },
            cost: total_cost(breakdown)
          }
        end

        def total_cost(breakdown)
          costs = breakdown.map { |e| e[:total_cost] }.compact
          costs.empty? ? nil : costs.sum
        end

        def format_totals_summary(totals)
          total_tokens = totals[:input] + totals[:output] + totals[:thinking]
          "Total: #{format_num(total_tokens)} tokens (#{token_parts(totals)}) | Cost: #{cost_string(totals[:cost])}"
        end

        def token_parts(totals)
          parts = ["↑#{format_num(totals[:input])}", "↓#{format_num(totals[:output])}"]
          parts << "💭#{format_num(totals[:thinking])}" if totals[:thinking].positive?
          parts.join(" ")
        end

      end
    end
  end
end
